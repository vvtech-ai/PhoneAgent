package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.localizedConfirmingDetailsStatus
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant.viewmodel.ConversationStateHolder
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.replaceChineseDigits
import com.vvtech.aiassistant.features.assistant_tasks.shouldClearCallResultForContinuation
import com.vvtech.aiassistant.features.assistant_voice.RecoverableVoiceTurnSubmissionPlan
import com.vvtech.aiassistant.features.assistant_voice.VoiceTurnRecoveryUnavailableException
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class ConversationSubmitActionHandler(
    private val viewModel: AssistantViewModel,
    private val conversationStateHolder: ConversationStateHolder
) {
    private val recognizedTurnSubmitter = ConversationRecognizedTurnSubmitter(viewModel)
    private val selectedContactTurnContext = PendingSelectedContactTurnContext()

    fun armSelectedContactForNextTurn(selectedContact: SelectedContactTaskContext?) {
        selectedContactTurnContext.arm(selectedContact)
    }

    fun clearSelectedContactForNextTurn() {
        selectedContactTurnContext.clear()
    }

    fun submitTextTask(rawText: String) {
        submitTextTaskWithContext(rawText, selectedContact = null)
    }

    private fun submitTextTaskWithContext(
        rawText: String,
        selectedContact: SelectedContactTaskContext?
    ) {
        with(viewModel) {
            val text = normalizeReservationAsrTranscript(replaceChineseDigits(rawText.trim()))
            if (text.isBlank()) {
                return
            }
            val turnSelectedContact = selectedContactTurnContext.take(selectedContact)
            autoResumeListeningJob?.cancel()
            pendingSpeechTurn?.cancel()
            consumeVisibleSelectionSheet()
            cancelTextProcessingStatusProgress()
            activeInteractionChannel = InteractionChannel.TEXT
            internalUiState.update {
                it.copy(agentContactInputSource = AgentContactInputSource.TYPED)
            }
            lastCommittedUserTranscript = text
            val clearCallResult = shouldClearCallResultForContinuation(
                internalUiState.value.taskStatus,
                internalUiState.value.agentCallResult
            )
            conversationStateHolder.prepareTextTurnSubmitting(
                clearCallResult = clearCallResult,
                statusText = currentAppText("正在处理，请稍候...", "Processing. Please wait...")
            )
            appendClarificationStep(VoiceRole.User, text)
            scheduleTextProcessingStatusProgress(text)
            viewModelScope.launch {
                refreshLocationIfPermitted(
                    force = agentSessionId == null,
                    reason = if (agentSessionId == null) "text_new_task" else "text_existing_task"
                )
                val sessionId = ensureAgentSession()
                val pendingId = AgentPendingToolPolicy.pendingToolCallIdForUserTurn(internalUiState.value)
                logSelectedContactForwarded(sessionId, turnSelectedContact)
                startStreamingAgentTurn(sessionId, text, pendingId, turnSelectedContact)
            }
        }
    }

    fun submitSingleFlowTask(
        rawText: String,
        voiceResponse: Boolean,
        selectedContact: SelectedContactTaskContext?
    ) {
        if (voiceResponse) {
            submitVoiceSupplementTaskWithContext(
                rawText = rawText,
                appendUserStep = true,
                selectedContact = selectedContact,
                inputSource = AgentContactInputSource.TYPED
            )
        } else {
            submitTextTaskWithContext(rawText, selectedContact)
        }
    }

    fun submitSceneSupplementTask(rawText: String) {
        with(viewModel) {
            when (activeInteractionChannel) {
                InteractionChannel.VOICE -> submitVoiceSupplementTaskWithContext(
                    rawText = rawText,
                    appendUserStep = true,
                    selectedContact = null,
                    inputSource = AgentContactInputSource.TYPED
                )
                InteractionChannel.TEXT, InteractionChannel.NONE -> submitTextTask(rawText)
            }
        }
    }

    fun submitVoiceSupplementTask(rawText: String, appendUserStep: Boolean = true) {
        submitVoiceSupplementTaskWithContext(
            rawText = rawText,
            appendUserStep = appendUserStep,
            selectedContact = null,
            inputSource = AgentContactInputSource.ASR
        )
    }

    private fun submitVoiceSupplementTaskWithContext(
        rawText: String,
        appendUserStep: Boolean,
        selectedContact: SelectedContactTaskContext?,
        inputSource: AgentContactInputSource
    ) {
        with(viewModel) {
            val text = normalizeReservationAsrTranscript(replaceChineseDigits(rawText.trim()))
            if (text.isBlank()) {
                return
            }
            if (internalUiState.value.agentDeviceContactSelection != null &&
                agentStreamHandler.tryHandleAgentDeviceContactVoiceSelection(text)
            ) {
                return
            }
            viewModelScope.launch {
                val recoveryPlan = runCatching {
                    voiceRecoverableTurnCoordinator.planSubmission(text)
                }.getOrElse { failure ->
                    if (failure is VoiceTurnRecoveryUnavailableException) {
                        applyNetworkTaskErrorState(failure.message)
                        return@launch
                    }
                    throw failure
                }
                if (recoveryPlan.originalAlreadyCommitted) {
                    internalLog(
                        "VOICE_TURN_RECOVERY original committed " +
                            "submitFollowup=${recoveryPlan.submitAfterOriginalCommit} " +
                            "sessionId=${agentSessionId.orEmpty()}"
                    )
                    val synced = syncConversationSnapshotForVoiceRecovery(
                        agentSessionId.orEmpty(),
                        "voice_turn_original_committed",
                    )
                    if (!synced) {
                        return@launch
                    }
                    voiceRecoverableTurnCoordinator.clear("original_committed_synchronized")
                    if (!recoveryPlan.submitAfterOriginalCommit) return@launch
                }
                submitPreparedVoiceTurn(
                    recoveryPlan = recoveryPlan.copy(
                        appendUserStep = recoveryPlan.appendUserStep && appendUserStep
                    ),
                    selectedContact = selectedContact,
                    inputSource = inputSource,
                )
            }
        }
    }

    private suspend fun AssistantViewModel.submitPreparedVoiceTurn(
        recoveryPlan: RecoverableVoiceTurnSubmissionPlan,
        selectedContact: SelectedContactTaskContext?,
        inputSource: AgentContactInputSource,
    ) {
        val text = recoveryPlan.text
        val turnSelectedContact = selectedContactTurnContext.take(selectedContact)
        var replacedUserStep = false
        if (recoveryPlan.replaceLastUserStep) {
            replacedUserStep = internalUiState.value.clarificationSteps.any {
                it.role == VoiceRole.User && !it.isUserActionEcho
            }
            internalUiState.update { state ->
                val index = state.clarificationSteps.indexOfLast {
                    it.role == VoiceRole.User && !it.isUserActionEcho
                }
                if (index < 0) {
                    state
                } else {
                    state.copy(
                        clarificationSteps = state.clarificationSteps.mapIndexed { itemIndex, step ->
                            if (itemIndex == index) step.copy(text = text) else step
                        }
                    )
                }
            }
        }
        autoResumeListeningJob?.cancel()
        pendingSpeechTurn?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        internalUiState.update { it.copy(agentContactInputSource = inputSource) }
        val inputGeneration = voiceRecognizedInputDedupTracker.markAccepted(text)
        internalLog(
            "VOICE_INPUT_DEDUP accepted generation=$inputGeneration source=voice_submit " +
                "text=${previewText(text)}"
        )
        lastCommittedUserTranscript = text
        val clearCallResult = shouldClearCallResultForContinuation(
            internalUiState.value.taskStatus,
            internalUiState.value.agentCallResult
        )
        conversationStateHolder.prepareVoiceSupplementSubmitting(
            clearCallResult = clearCallResult,
            statusText = localizedConfirmingDetailsStatus()
        )
        if (recoveryPlan.appendUserStep || recoveryPlan.replaceLastUserStep && !replacedUserStep) {
            appendClarificationStep(VoiceRole.User, text)
        }
        scheduleTextProcessingStatusProgress(text)
        val sessionId = ensureAgentSession()
        val pendingId = AgentPendingToolPolicy.pendingToolCallIdForUserTurn(internalUiState.value)
        logSelectedContactForwarded(sessionId, turnSelectedContact)
        startStreamingAgentTurn(
            sessionId = sessionId,
            message = text,
            pendingToolCallId = pendingId,
            selectedContact = turnSelectedContact,
            supersedesCommandId = recoveryPlan.supersedesCommandId,
        )
    }

    fun drainQueuedRecognizedTurn() {
        with(viewModel) {
            val queued = queuedRecognizedTurns.pollFirst()?.trim().orEmpty()
            if (queued.isBlank()) {
                return
            }
            internalLog(
                "drainQueuedRecognizedTurn runId=$activeDialogRunId scene=${internalUiState.value.sceneType} " +
                    "remaining=${queuedRecognizedTurns.size} text=${previewText(queued)} processing=${internalUiState.value.processingTurn}"
            )
            if (!internalUiState.value.processingTurn && pendingSpeechTurn?.isActive != true) {
                submitRecognizedTurn(queued)
            } else {
                queuedRecognizedTurns.addFirst(queued)
            }
        }
    }

    fun submitRecognizedTurn(
        text: String,
        structuredUnderstanding: StructuredAssistantUnderstanding? = null,
        assistantResponseText: String? = null
    ) {
        recognizedTurnSubmitter.submitRecognizedTurn(
            text = text,
            structuredUnderstanding = structuredUnderstanding,
            assistantResponseText = assistantResponseText,
            submitVoiceSupplementTask = ::submitVoiceSupplementTask,
            drainQueuedRecognizedTurn = ::drainQueuedRecognizedTurn
        )
    }

    private fun logSelectedContactForwarded(
        sessionId: String,
        selectedContact: SelectedContactTaskContext?
    ) {
        if (selectedContact == null) return
        viewModel.internalLog(
            "SELECTED_CONTACT_CONTEXT_FORWARDED sessionId=$sessionId " +
                "source=${selectedContact.source} hasName=${selectedContact.name.isNotBlank()} " +
                "hasPhone=${selectedContact.phone.isNotBlank()}"
        )
    }
}

internal class PendingSelectedContactTurnContext {
    private var pending: SelectedContactTaskContext? = null

    fun arm(selectedContact: SelectedContactTaskContext?) {
        pending = selectedContact
    }

    fun take(explicit: SelectedContactTaskContext?): SelectedContactTaskContext? {
        val selectedContact = explicit ?: pending
        pending = null
        return selectedContact
    }

    fun clear() {
        pending = null
    }
}
