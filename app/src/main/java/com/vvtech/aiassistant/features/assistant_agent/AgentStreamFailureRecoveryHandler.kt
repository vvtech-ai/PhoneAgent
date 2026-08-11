package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.containsTransportNetworkError
import com.vvtech.aiassistant.features.assistant.localizedVoiceRecoveryResumeStatus
import com.vvtech.aiassistant.features.assistant.networkTaskErrorStatusMessage
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingError
import com.vvtech.aiassistant.features.assistant.voiceRecoveryDecision
import com.vvtech.aiassistant.features.assistant_voice.VoiceListenTriggers
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal const val CALL_OUTCOME_PENDING_STATUS = "正在确认通话结果"
internal const val CALL_OUTCOME_SYNC_PENDING_STATUS = "通话已结束，结果同步中，请稍后刷新"
internal const val CALL_STATUS_SYNC_PENDING_STATUS = "正在确认通话状态"

internal data class AgentStreamFailureRecoveryRuntime(
    val stateProvider: () -> Index9AssistantUiState,
    val isVoiceMode: () -> Boolean,
    val currentVoiceLanguage: () -> VoiceLanguage,
    val hasActiveBatchCallStream: () -> Boolean,
    val isOutboundCallAudioSuppressed: () -> Boolean,
    val batchSyncPendingStatusText: () -> String,
    val sessionIdProvider: () -> String? = { null },
    val nowMs: () -> Long = { System.currentTimeMillis() }
)

internal data class AgentStreamFailureRecoveryCallbacks(
    val cancelTextProcessingStatusProgress: () -> Unit,
    val mutateStep: (Int, (ClarificationStep) -> ClarificationStep) -> Unit,
    val finalizeStep: (Int) -> Unit,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val clearActiveBatchCallState: () -> Unit,
    val stopApiListening: () -> Unit,
    val syncCurrentTimeline: () -> Unit,
    val loadConversations: () -> Unit,
    val applyNetworkTaskErrorState: (String?) -> Unit,
    val markTaskErrorRecoveryInProgress: (String) -> Unit,
    val startApiListening: (String) -> Unit,
    val suspendDialogAudioForCall: (String) -> Unit,
    val releaseStreamOwnership: (Int) -> Unit = {},
    val onRecoverableVoiceTurnNetworkFailure: () -> Unit = {},
)

internal class AgentStreamFailureRecoveryHandler(
    private val runtime: AgentStreamFailureRecoveryRuntime,
    private val callbacks: AgentStreamFailureRecoveryCallbacks
) {
    fun abortPlaceholder(stepIndex: Int, errorText: String) {
        if (runtime.isVoiceMode()) {
            clearRecoverablePlaceholder(stepIndex)
            return
        }
        val safeErrorText = sanitizeUserFacingError(errorText, runtime.currentVoiceLanguage())
        callbacks.mutateStep(stepIndex) { step ->
            AgentStreamPlaceholderStepReducer.applyErrorPlaceholder(step, safeErrorText)
        }
        callbacks.finalizeStep(stepIndex)
    }

    fun handleStreamFailure(stepIndex: Int, throwable: Throwable, fallback: String) {
        try {
            handleStreamFailureInternal(stepIndex, throwable, fallback)
        } finally {
            callbacks.releaseStreamOwnership(stepIndex)
        }
    }

    private fun handleStreamFailureInternal(
        stepIndex: Int,
        throwable: Throwable,
        fallback: String,
    ) {
        val language = runtime.currentVoiceLanguage()
        val structuredFailure = (throwable as? AgentStreamFailure)?.failure
        logFailureDecision(
            eventType = "AGENT_STREAM_FAILED",
            trigger = VoiceListenTriggers.AgentTransportFailureRecovery,
            result = "received",
            reason = "stream_transport_failure",
            throwable = throwable
        )
        if (runtime.hasActiveBatchCallStream()) {
            callbacks.cancelTextProcessingStatusProgress()
            callbacks.finalizeStep(stepIndex)
            callbacks.clearActiveBatchCallState()
            callbacks.stopApiListening()
            callbacks.updateState {
                AgentStreamErrorUiStateReducer.applyBatchSyncPending(
                    state = it,
                    statusText = runtime.batchSyncPendingStatusText(),
                    clearError = true
                )
            }
            callbacks.loadConversations()
            return
        }
        if (hasActiveSingleCall(runtime.stateProvider())) {
            logFailureDecision(
                eventType = "CALL_STATUS_SYNC_PENDING",
                trigger = VoiceListenTriggers.AgentTransportFailureRecovery,
                result = "sync_pending",
                reason = "agent_failure_while_call_active",
                throwable = throwable
            )
            callbacks.cancelTextProcessingStatusProgress()
            if (runtime.isVoiceMode()) {
                clearRecoverablePlaceholder(stepIndex)
            } else {
                callbacks.finalizeStep(stepIndex)
            }
            callbacks.stopApiListening()
            callbacks.updateState {
                AgentStreamErrorUiStateReducer.applyBatchSyncPending(
                    state = it,
                    statusText = CALL_STATUS_SYNC_PENDING_STATUS,
                    clearError = true
                )
            }
            callbacks.syncCurrentTimeline()
            callbacks.loadConversations()
            return
        }
        if (isAwaitingCompletedCallOutcome(runtime.stateProvider())) {
            logFailureDecision(
                eventType = "CALL_OUTCOME_WAITING",
                trigger = VoiceListenTriggers.AgentTransportFailureRecovery,
                result = "sync_pending",
                reason = "transport_failure_while_waiting_call_result",
                throwable = throwable
            )
            callbacks.cancelTextProcessingStatusProgress()
            if (runtime.isVoiceMode()) {
                clearRecoverablePlaceholder(stepIndex)
            } else {
                callbacks.finalizeStep(stepIndex)
            }
            callbacks.stopApiListening()
            callbacks.updateState {
                AgentStreamErrorUiStateReducer.applyBatchSyncPending(
                    state = it,
                    statusText = CALL_OUTCOME_SYNC_PENDING_STATUS,
                    clearError = true
                )
            }
            callbacks.syncCurrentTimeline()
            callbacks.loadConversations()
            return
        }
        val isNetworkFailure = structuredFailure?.let { failure ->
            if (failure.hasStructuredFailure) failure.isNetworkFailure else null
        } ?: containsTransportNetworkError(throwable.message)
        if (isNetworkFailure) {
            callbacks.cancelTextProcessingStatusProgress()
            if (runtime.isVoiceMode()) {
                callbacks.onRecoverableVoiceTurnNetworkFailure()
            }
            if (runtime.isVoiceMode()) {
                clearRecoverablePlaceholder(stepIndex)
            } else {
                abortPlaceholder(stepIndex, networkTaskErrorStatusMessage(language))
            }
            callbacks.applyNetworkTaskErrorState(throwable.message)
            return
        }
        if (!runtime.isVoiceMode()) {
            val msg = if (structuredFailure?.hasStructuredFailure == true) {
                structuredFailure.message.ifBlank { fallback }
            } else {
                sanitizeUserFacingError(throwable.message, language, fallback)
            }
            callbacks.cancelTextProcessingStatusProgress()
            callbacks.finalizeStep(stepIndex)
            callbacks.updateState {
                AgentStreamErrorUiStateReducer.applyExecutionError(it, errorText = msg)
            }
            return
        }
        callbacks.cancelTextProcessingStatusProgress()
        clearRecoverablePlaceholder(stepIndex)
        callbacks.markTaskErrorRecoveryInProgress("EXECUTION_ERROR")
        val status = structuredFailure
            ?.takeIf { it.hasStructuredFailure }
            ?.message
            ?.takeIf { it.isNotBlank() }
            ?: voiceRecoveryDecision(
                throwable.message,
                language,
                localizedVoiceRecoveryResumeStatus(language)
            ).status
        callbacks.updateState {
            AgentStreamErrorUiStateReducer.applyVoiceRecovery(
                state = it,
                statusText = status,
                resetManualPause = true
            )
        }
        resumeListeningAfterAgentRecovery(VoiceListenTriggers.AgentTransportFailureRecovery)
    }

    fun handleActionFailure(
        stepIndex: Int,
        throwable: Throwable,
        fallback: String,
        beforeRecover: (() -> Unit)? = null
    ) {
        beforeRecover?.invoke()
        handleStreamFailure(stepIndex, throwable, fallback)
    }

    fun clearRecoverablePlaceholder(stepIndex: Int) {
        callbacks.updateState { state ->
            state.copy(
                clarificationSteps = AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder(
                    steps = state.clarificationSteps,
                    stepIndex = stepIndex
                )
            )
        }
    }

    fun resetStreamingStepForRetry(stepIndex: Int) {
        callbacks.mutateStep(stepIndex) {
            AgentStreamPlaceholderStepReducer.newRetryStep(nowMs = runtime.nowMs())
        }
    }

    fun resumeListeningAfterAgentRecovery(
        trigger: String = VoiceListenTriggers.AgentTransportFailureRecovery
    ) {
        if (runtime.hasActiveBatchCallStream()) {
            logFailureDecision("AGENT_RECOVERY_LISTEN_SKIPPED", trigger, "skipped", "batch_call_active")
            return
        }
        val state = runtime.stateProvider()
        if (!runtime.isVoiceMode() || state.voiceManuallyPaused) {
            logFailureDecision(
                "AGENT_RECOVERY_LISTEN_SKIPPED",
                trigger,
                "skipped",
                if (!runtime.isVoiceMode()) "not_voice_mode" else "voice_manually_paused"
            )
            return
        }
        if (runtime.isOutboundCallAudioSuppressed()) {
            logFailureDecision(
                "AGENT_RECOVERY_LISTEN_BLOCKED",
                trigger,
                "blocked",
                "call_audio_suppressed"
            )
            callbacks.suspendDialogAudioForCall("agent_recovery_call_active")
            return
        }
        logFailureDecision(
            "AGENT_RECOVERY_LISTEN_REQUESTED",
            trigger,
            "requested",
            if (isAwaitingCompletedCallOutcome(state)) "call_outcome_pending" else "recovery_ready"
        )
        callbacks.startApiListening(trigger)
    }

    private fun isAwaitingCompletedCallOutcome(state: Index9AssistantUiState): Boolean {
        return state.status == CALL_OUTCOME_PENDING_STATUS ||
            state.callPageData.status == CALL_OUTCOME_PENDING_STATUS
    }

    private fun hasActiveSingleCall(state: Index9AssistantUiState): Boolean {
        return state.currentCallId?.isNotBlank() == true
    }

    private fun logFailureDecision(
        eventType: String,
        trigger: String,
        result: String,
        reason: String,
        throwable: Throwable? = null
    ) {
        val state = runtime.stateProvider()
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.AGENT,
            eventType = eventType,
            sessionId = runtime.sessionIdProvider(),
            taskId = state.taskId,
            callId = state.currentCallId,
            trigger = trigger,
            result = result,
            reason = reason,
            attributes = mapOf(
                "exceptionType" to throwable?.javaClass?.simpleName,
                "errorCode" to (throwable as? AgentStreamFailure)?.failure?.errorCode,
                "errorCategory" to (throwable as? AgentStreamFailure)?.failure?.category,
                "retryable" to (throwable as? AgentStreamFailure)?.failure?.retryable?.toString(),
                "traceId" to (throwable as? AgentStreamFailure)?.failure?.traceId,
                "activeSingleCall" to hasActiveSingleCall(state).toString(),
                "callOutcomePending" to isAwaitingCompletedCallOutcome(state).toString(),
                "voiceMode" to runtime.isVoiceMode().toString()
            )
        )
        if (throwable != null) {
            RuntimeStateLogger.warn(event, throwable)
        } else {
            RuntimeStateLogger.info(event)
        }
    }
}
