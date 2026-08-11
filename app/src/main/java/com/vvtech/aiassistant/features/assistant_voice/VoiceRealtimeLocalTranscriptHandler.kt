package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.localizedConfirmingDetailsStatus
import com.vvtech.aiassistant.features.assistant.localizedListeningStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.detectLocalSceneHint
import com.vvtech.aiassistant.features.assistant.viewmodel.isBackendStateMachineScene
import com.vvtech.aiassistant.features.assistant.viewmodel.maxStage
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.replaceChineseDigits
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.flow.update

internal interface VoiceRealtimeLocalTranscriptCallbacks {
    fun markAsrFinal(source: String)
    fun markAsrPartial(text: String, source: String)
    fun recordAgentSubmitting(text: String, source: String)
    fun stopLiveTranscription()
    fun enqueueRecognizedTurn(text: String)
}

internal class VoiceRealtimeLocalTranscriptHandler(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceRealtimeLocalTranscriptCallbacks
) {
    fun handleRealtimeLocalTranscript(text: String, definite: Boolean) { with(viewModel) {
        if (localTtsPlaying) {
            val trimmed = text.trim()
            if (trimmed.isBlank()) {
                internalLog(
                    "handleRealtimeLocalTranscript suppressed blank localTtsPlaying=true " +
                        "runId=$activeDialogRunId definite=$definite"
                )
                return
            }
            internalLog(
                "handleRealtimeLocalTranscript ignored reason=${TaskVoiceCloseReason.NoInterruptCapability.logKey} " +
                    "localTtsPlaying=true " +
                    "runId=$activeDialogRunId definite=$definite text=${previewText(trimmed)}"
            )
            return
        }
        val currentScene = activeDialogContext?.sceneType ?: internalUiState.value.sceneType
        val normalized = replaceChineseDigits(text.trim())
        if (normalized.isBlank()) {
            if (definite) {
                callbacks.markAsrFinal("realtime_local_blank")
                internalLog(
                    "handleRealtimeLocalTranscript ignored blank definite runId=$activeDialogRunId scene=$currentScene " +
                        "dialogKey=${activeDialogContext?.dialogKey} raw=${previewText(text)}"
                )
            }
            return
        }
        if (looksLikeAsrMetadata(normalized)) {
            if (definite) {
                callbacks.markAsrFinal("realtime_local_metadata")
            }
            AppFileLogger.w(
                "VoiceRuntimeHandler",
                "ASR final transcript filtered (SDK metadata): $normalized definite=$definite"
            )
            return
        }
        if (definite && voiceRecognizedInputDedupTracker.isDuplicateInCurrentInput(normalized)) {
            internalLog(
                "handleRealtimeLocalTranscript duplicate definite runId=$activeDialogRunId " +
                    "scene=$currentScene generation=${voiceRecognizedInputDedupTracker.currentGeneration()} " +
                    "dialogKey=${activeDialogContext?.dialogKey} text=${previewText(normalized)}"
            )
            return
        }
        if (definite) {
            internalLog(
                "handleRealtimeLocalTranscript definite runId=$activeDialogRunId scene=$currentScene " +
                    "dialogKey=${activeDialogContext?.dialogKey} raw=${previewText(text)} " +
                    "normalized=${previewText(normalized)}"
            )
        }
        if (definite) {
            callbacks.markAsrFinal("realtime_local")
        } else {
            callbacks.markAsrPartial(normalized, "realtime_local")
        }
        val recoverableBaseText = voiceRecoverableTurnCoordinator.recoverableBaseText()
        val displayedTranscript = mergeManualAsrTranscript(recoverableBaseText, normalized)
        internalUiState.update {
            it.copy(
                stage = maxStage(it.stage, AssistantStage.Clarifying),
                voiceConnecting = false,
                voiceActive = true,
                listening = !definite,
                processingTurn = if (definite) true else it.processingTurn,
                error = null,
                status = if (definite) {
                    localizedConfirmingDetailsStatus(currentScene)
                } else {
                    localizedListeningStatus()
                },
                liveUserTranscript = if (definite) null else displayedTranscript,
                liveAssistantTranscript = if (definite) null else it.liveAssistantTranscript
            )
        }
        if (!definite) {
            return
        }
        val localSceneHint = if (currentScene == "GENERAL") detectLocalSceneHint(normalized) else "GENERAL"
        val sceneSwitchHint = currentScene == "GENERAL" && localSceneHint != "GENERAL"
        val backendStateMachineScene = isBackendStateMachineScene(currentScene)
        val requiresImmediateFallbackSubmit =
            backendSpeechFallbackActive || activeDialogContext == null || sceneSwitchHint || backendStateMachineScene
        if (sceneSwitchHint || backendStateMachineScene) {
            pendingStructuredRecognizedTurn = null
            latestRealtimeAssistantReplyForBackend = null
            suppressAssistantEventsForCurrentRun = true
            internalLog(
                "handleRealtimeLocalTranscript backendOwnedSubmit runId=$activeDialogRunId scene=$currentScene " +
                    "localSceneHint=$localSceneHint backendOwned=$backendStateMachineScene " +
                    "text=${previewText(normalized)}"
            )
            callbacks.stopLiveTranscription()
        }
        val inputGeneration = voiceRecognizedInputDedupTracker.markAccepted(normalized)
        internalLog(
            "VOICE_INPUT_DEDUP accepted generation=$inputGeneration source=realtime_local_final " +
                "text=${previewText(normalized)}"
        )
        lastCommittedUserTranscript = displayedTranscript
        callbacks.recordAgentSubmitting(normalized, "realtime_local_final")
        if (recoverableBaseText.isNullOrBlank()) {
            appendClarificationStep(VoiceRole.User, normalized)
        }
        if (requiresImmediateFallbackSubmit) {
            callbacks.enqueueRecognizedTurn(normalized)
        } else {
            pendingStructuredRecognizedTurn = normalized
            internalLog(
                "handleRealtimeLocalTranscript waitingStructured runId=$activeDialogRunId scene=$currentScene " +
                    "dialogKey=${activeDialogContext?.dialogKey} text=${previewText(normalized)}"
            )
        }
    } }

    fun submitPendingStructuredTurn(
        understanding: StructuredAssistantUnderstanding?,
        reason: String
    ): Boolean { with(viewModel) {
        val recognized = pendingStructuredRecognizedTurn?.trim().orEmpty()
        if (recognized.isBlank()) {
            internalLog(
                "submitPendingStructuredTurn skipped reason=$reason noPendingText " +
                    "runId=$activeDialogRunId scene=${activeDialogContext?.sceneType} " +
                    "dialogKey=${activeDialogContext?.dialogKey} voiceTaskId=$voiceTaskId " +
                    "uiTaskId=${internalUiState.value.taskId} pendingFreshTask=$pendingFreshTask " +
                    "structuredScene=${understanding?.scene} " +
                    "slotKeys=${understanding?.slotUpdates?.keys ?: emptySet<String>()}"
            )
            return false
        }
        pendingStructuredRecognizedTurn = null
        internalLog(
            "submitPendingStructuredTurn runId=$activeDialogRunId reason=$reason scene=${activeDialogContext?.sceneType} " +
                "dialogKey=${activeDialogContext?.dialogKey} text=${previewText(recognized)} " +
                "voiceTaskId=$voiceTaskId uiTaskId=${internalUiState.value.taskId} pendingFreshTask=$pendingFreshTask " +
                "structuredScene=${understanding?.scene} structuredConfidence=${understanding?.sceneConfidence} " +
                "slotKeys=${understanding?.slotUpdates?.keys ?: emptySet<String>()}"
        )
        val assistantResponseText = latestRealtimeAssistantReplyForBackend
            ?.trim()
            ?.takeIf { it.isNotBlank() }
        latestRealtimeAssistantReplyForBackend = null
        submitRecognizedTurn(recognized, understanding, assistantResponseText)
        return true
    } }

    fun submitPendingStructuredFallbackIfNeeded(): Boolean { with(viewModel) {
        internalLog(
            "submitPendingStructuredFallbackIfNeeded runId=$activeDialogRunId " +
                "scene=${activeDialogContext?.sceneType} dialogKey=${activeDialogContext?.dialogKey} " +
                "pendingText=${previewText(pendingStructuredRecognizedTurn.orEmpty())} " +
                "voiceTaskId=$voiceTaskId uiTaskId=${internalUiState.value.taskId} pendingFreshTask=$pendingFreshTask"
        )
        return submitPendingStructuredTurn(null, reason = "assistant_turn_finished_fallback")
    } }
}
