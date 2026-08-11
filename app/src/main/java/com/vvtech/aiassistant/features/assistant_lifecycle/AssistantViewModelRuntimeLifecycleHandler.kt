package com.vvtech.aiassistant.features.assistant_lifecycle

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.flow.update

internal class AssistantViewModelRuntimeLifecycleHandler(
    private val viewModel: AssistantViewModel
) {
    fun initialize() {
        if (viewModel.initialized) {
            logLifecycle("APP_RUNTIME_INITIALIZE_SKIPPED", "skipped", "already_initialized")
            return
        }
        logLifecycle("APP_RUNTIME_INITIALIZE_STARTED", "started", "view_model_initialize")
        viewModel.initialized = true
        viewModel.registerTaskErrorNetworkCallback()
        viewModel.resetToIdleHome()
        viewModel.refreshHistory()
        viewModel.ttsBridge.onAllPlaybackComplete = {
            viewModel.voiceDuplexCoordinator.onAgentTtsPlaybackComplete()
        }
        viewModel.ttsBridge.onPlaybackFailed = { throwable ->
            viewModel.voiceDuplexCoordinator.onAgentTtsPlaybackFailed(throwable)
        }
        viewModel.ttsBridge.onPlaybackStarted = {
            viewModel.voiceDuplexCoordinator.onAgentTtsPlaybackStarted()
        }
        viewModel.ttsBridge.onBeforeSentenceSynthesis = { sentence ->
            viewModel.voiceDuplexCoordinator.onAgentTtsSentencePreparing(sentence)
        }
        viewModel.ttsBridge.onBeforeAudioEnqueue = {
            viewModel.voiceDuplexCoordinator.onAgentTtsAudioReady()
        }
        logLifecycle("APP_RUNTIME_INITIALIZE_COMPLETED", "completed", "callbacks_registered")
    }

    fun onAccountIdentityChanged(hasSignedInAccount: Boolean) {
        logLifecycle(
            "APP_ACCOUNT_IDENTITY_CHANGED",
            if (hasSignedInAccount) "signed_in" else "signed_out",
            "account_identity_callback"
        )
        if (!hasSignedInAccount) {
            viewModel.resetToIdleHome()
            return
        }
        viewModel.refreshHistory()
    }

    fun onRetry() {
        logLifecycle("APP_RUNTIME_RETRY_STARTED", "started", "user_retry")
        viewModel.pendingSpeechTurn?.cancel()
        viewModel.autoResumeListeningJob?.cancel()
        viewModel.pendingFreshTask = false
        viewModel.speechFallbackStarted = false
        viewModel.platformSpeechFallbackStarted = false
        viewModel.pendingAiCallLaunch = false
        viewModel.outboundCallAudioSuppressed = false
        viewModel.pendingStructuredRecognizedTurn = null
        viewModel.pendingDetailActionable = null
        viewModel.detailSupplementCompletedTaskId = null
        viewModel.detailSupplementContactTaskId = null
        viewModel.detailSupplementContactValue = null
        viewModel.detailSupplementInfoTaskId = null
        viewModel.detailSupplementInfoValue = null
        viewModel.pendingSelectionContinuation = null
        viewModel.stopVoiceInteraction()
        viewModel.resetToIdleHome()
        viewModel.internalUiState.update { it.copy(showAiCallPage = false) }
        viewModel.refreshHistory()
        logLifecycle("APP_RUNTIME_RETRY_COMPLETED", "completed", "state_reset")
    }

    fun onCleared() {
        logLifecycle("APP_RUNTIME_CLEAR_STARTED", "started", "view_model_cleared")
        viewModel.unregisterTaskErrorNetworkCallback()
        viewModel.stopCallSessionPolling()
        viewModel.stopTakeoverAudioSocket()
        viewModel.takeoverReconnectJob?.cancel()
        viewModel.assistantSpeechPlayer.stop()
        viewModel.taskAsrClient.release()
        viewModel.ttsBridge.release()
        viewModel.stopRealtimeSession()
        logLifecycle("APP_RUNTIME_CLEAR_COMPLETED", "completed", "resources_released")
    }

    private fun logLifecycle(eventType: String, result: String, reason: String) {
        val state = viewModel.internalUiState.value
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.APP,
                eventType = eventType,
                sessionId = viewModel.agentSessionId,
                taskId = state.taskId,
                callId = state.currentCallId,
                result = result,
                reason = reason,
                attributes = mapOf(
                    "processingTurn" to state.processingTurn.toString(),
                    "voiceActive" to state.voiceActive.toString()
                )
            )
        )
    }
}
