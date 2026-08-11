package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.containsTransportNetworkError
import com.vvtech.aiassistant.features.assistant.localizedConfirmingDetailsStatus
import com.vvtech.aiassistant.features.assistant.localizedNoValidSpeechStatus
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingError
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUiStateReducer
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultUserId
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.detectLocalSceneHint
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.replaceChineseDigits
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class ConversationRecognizedTurnSubmitter(
    private val viewModel: AssistantViewModel
) {
    private val sessionTurnUseCase = AssistantSessionTurnUseCase(viewModel.repository)

    fun submitRecognizedTurn(
        text: String,
        structuredUnderstanding: StructuredAssistantUnderstanding? = null,
        assistantResponseText: String? = null,
        submitVoiceSupplementTask: (String, Boolean) -> Unit,
        drainQueuedRecognizedTurn: () -> Unit
    ) {
        with(viewModel) {
            val recognized = normalizeReservationAsrTranscript(replaceChineseDigits(text.trim()))
            autoResumeListeningJob?.cancel()
            consumeVisibleSelectionSheet()
            val uiTaskId = internalUiState.value.taskId
            val resolvedTaskId = activeVoiceTaskId()
            if (voiceTaskId.isNullOrBlank() && !resolvedTaskId.isNullOrBlank()) {
                voiceTaskId = resolvedTaskId
            }
            val startFresh = pendingFreshTask && resolvedTaskId.isNullOrBlank()
            val currentScene = activeDialogContext?.sceneType ?: internalUiState.value.sceneType
            if (recognized.isBlank()) {
                internalUiState.update {
                    AssistantUiStateReducer.applyEmptyRecognizedTurn(
                        it,
                        localizedNoValidSpeechStatus()
                    )
                }
                return
            }
            if (activeInteractionChannel == InteractionChannel.VOICE) {
                internalLog(
                    "submitRecognizedTurn routed to agent stream runId=$activeDialogRunId " +
                        "scene=$currentScene text=${previewText(recognized)}"
                )
                submitVoiceSupplementTask(
                    recognized,
                    recognized != lastCommittedUserTranscript
                )
                return
            }
            clearConsumedSelectionSheetSuppression()

            internalLog(
                "submitRecognizedTurn start runId=$activeDialogRunId scene=$currentScene " +
                    "dialogKey=${activeDialogContext?.dialogKey} voiceTaskId=$voiceTaskId uiTaskId=$uiTaskId " +
                    "resolvedTaskId=$resolvedTaskId " +
                    "pendingFreshTask=$pendingFreshTask startFresh=$startFresh " +
                    "text=${previewText(recognized)} assistantResponse=${previewText(assistantResponseText)}"
            )
            pendingSpeechTurn?.cancel()
            if (recognized != lastCommittedUserTranscript) {
                lastCommittedUserTranscript = recognized
                appendClarificationStep(VoiceRole.User, recognized)
            }
            internalUiState.update { state ->
                state.copy(
                    stage = AssistantStage.Clarifying,
                    voiceActive = true,
                    voiceManuallyPaused = false,
                    listening = false,
                    processingTurn = true,
                    error = null,
                    status = localizedConfirmingDetailsStatus(currentScene),
                    liveUserTranscript = null
                )
            }
            val speechTurnJob = viewModelScope.launch {
                if (startFresh) {
                    // Do not wait for location on the critical voice path; use the latest cached context.
                    viewModelScope.launch {
                        refreshLocationIfPermitted(
                            force = true,
                            reason = "voice_first_turn"
                        )
                    }
                }
                if (currentScene == "GENERAL" && detectLocalSceneHint(recognized) != "GENERAL") {
                    internalLog(
                        "submitRecognizedTurn defers scene dialog switch to backend state machine " +
                            "runId=$activeDialogRunId text=${previewText(recognized)}"
                    )
                }
                val contactResolution = resolveContactPayload(recognized)
                internalLog(
                    "submitRecognizedTurn sendMessage runId=$activeDialogRunId scene=$currentScene " +
                        "voiceTaskId=$voiceTaskId uiTaskId=${internalUiState.value.taskId} resolvedTaskId=$resolvedTaskId " +
                        "startFresh=$startFresh text=${previewText(recognized)} " +
                        "assistantResponse=${previewText(assistantResponseText)} " +
                        "contactName=${contactResolution?.contactName} contactPhone=${contactResolution?.phoneNumber} " +
                        "structuredScene=${structuredUnderstanding?.scene} " +
                        "structuredConfidence=${structuredUnderstanding?.sceneConfidence} " +
                        "structuredSlotKeys=${structuredUnderstanding?.slotUpdates?.keys ?: emptySet<String>()}"
                )
                runCatching {
                    sessionTurnUseCase.sendVoiceMessage(
                        AssistantVoiceMessageInput(
                            userId = DefaultUserId,
                            taskId = resolvedTaskId,
                            startFresh = startFresh,
                            message = recognized,
                            userContext = latestUserContext,
                            contactResolution = contactResolution,
                            structuredUnderstanding = structuredUnderstanding,
                            assistantResponseText = assistantResponseText,
                            languageCode = voiceLanguageCode
                        )
                    )
                }.onSuccess { response ->
                    val messageTypes = response.messages.takeLast(3).joinToString(",") { it.type }
                    internalLog(
                        "submitRecognizedTurn success runId=$activeDialogRunId scene=${response.session.sceneType} " +
                            "taskId=${response.session.taskId} taskStatus=${response.session.taskStatus} " +
                            "messageCount=${response.messages.size} lastTypes=$messageTypes " +
                            "hasRestaurantCard=${response.messages.any { it.restaurantCard != null }} " +
                            "hasHotelCard=${response.messages.any { it.hotelCard != null }} " +
                            "hasCallConfirmCard=${response.messages.any { it.callConfirmCard != null }}"
                    )
                    applySession(response)
                }.onFailure { throwable ->
                    internalLog(
                        "submitRecognizedTurn failed runId=$activeDialogRunId scene=$currentScene taskId=$voiceTaskId " +
                            "text=${previewText(recognized)} error=${throwable.message}"
                    )
                    if (containsTransportNetworkError(throwable.message)) {
                        applyNetworkTaskErrorState(throwable.message)
                        return@onFailure
                    }
                    internalUiState.update {
                        it.copy(
                            processingTurn = false,
                            error = sanitizeUserFacingError(
                                throwable.message,
                                currentVoiceLanguage(),
                                unsentRecognizedTurnMessage()
                            ),
                            status = if (it.voiceActive) {
                                continueSpeakingStatus()
                            } else {
                                repeatToContinueStatus()
                            }
                        )
                    }
                }
            }
            pendingSpeechTurn = speechTurnJob
            speechTurnJob.invokeOnCompletion { cause ->
                if (pendingSpeechTurn === speechTurnJob) {
                    pendingSpeechTurn = null
                }
                internalLog(
                    "submitRecognizedTurn completed runId=$activeDialogRunId scene=${internalUiState.value.sceneType} " +
                        "text=${previewText(recognized)} cause=${cause?.message ?: "none"} " +
                        "queued=${queuedRecognizedTurns.size}"
                )
                viewModelScope.launch {
                    drainQueuedRecognizedTurn()
                }
            }
        }
    }

    private fun AssistantViewModel.unsentRecognizedTurnMessage(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "That message was not sent."
        VoiceLanguage.Japanese -> "この発話を送信できませんでした。"
        VoiceLanguage.Chinese -> "这句话没有发出去"
    }

    private fun AssistantViewModel.continueSpeakingStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Keep speaking. I will catch up."
        VoiceLanguage.Japanese -> "そのまま話してください。続けて処理します。"
        VoiceLanguage.Chinese -> "你继续说，我会重新跟上"
    }

    private fun AssistantViewModel.repeatToContinueStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Please say that again and I will continue."
        VoiceLanguage.Japanese -> "もう一度話してください。続けて処理します。"
        VoiceLanguage.Chinese -> "你可以再说一遍，我继续接"
    }
}
