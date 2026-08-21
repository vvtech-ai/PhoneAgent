package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal data class TaskCallSessionTerminalStatusControllerDeps(
    val state: TaskCallSessionStatusApplyStateAccess,
    val runtime: TaskCallSessionTerminalStatusRuntimeActions,
    val logging: TaskCallSessionStatusApplyLogging
)

internal data class TaskCallSessionTerminalStatusRuntimeActions(
    val stopCallSessionPolling: () -> Unit,
    val stopTakeoverAudioSocket: () -> Unit,
    val clearTakeoverProtectWindow: () -> Unit,
    val applyCallOutcomePendingDisplay: (pendingText: String) -> Unit,
    val syncDeferredAgentOutcome: (callId: String) -> Unit,
)

internal class TaskCallSessionTerminalStatusController(
    private val deps: TaskCallSessionTerminalStatusControllerDeps
) {
    fun applyDeferredAgentOutcome(
        response: CallSessionStatusResponse,
        appendNote: Boolean,
        currentState: Index9AssistantUiState,
        normalizedDialogue: String
    ) {
        logTerminal(
            eventType = "CALL_TRANSPORT_TERMINAL_DEFERRED",
            response = response,
            state = currentState,
            stateAfter = "waiting_agent_outcome",
            result = "deferred",
            reason = "awaiting_call_result"
        )
        deps.logging.logStatusResponse(
            "applyCallSessionStatus_defer_terminal",
            response,
            appendNote,
            currentState,
            normalizedDialogue
        )
        val pendingText = currentAppText("正在确认通话结果", "Confirming call result")
        deps.logging.internalLog(
            "defer transport terminal status until reportCallOutcome " +
                "taskId=${response.taskId} callId=${response.callId} " +
                "callState=${response.callState} handoff=${response.handoffMode} " +
                "resultCode=${response.resultCode} statusMessage=${response.statusMessage}"
        )
        deps.state.setPendingAiCallLaunch(false)
        deps.runtime.stopCallSessionPolling()
        deps.runtime.stopTakeoverAudioSocket()
        deps.state.setLastAppliedDialogueDetail(null)
        deps.runtime.clearTakeoverProtectWindow()
        deps.runtime.applyCallOutcomePendingDisplay(pendingText)
        logTerminal(
            eventType = "CALL_OUTCOME_WAITING",
            response = response,
            state = deps.state.currentState(),
            stateAfter = "outcome_pending",
            result = "waiting",
            reason = "transport_terminal_without_agent_result"
        )
        deps.runtime.syncDeferredAgentOutcome(response.callId)
    }

    fun applyTerminalStatus(
        response: CallSessionStatusResponse,
        currentState: Index9AssistantUiState,
        appendNote: Boolean,
        normalizedDialogue: String
    ) {
        logTerminal(
            eventType = "CALL_TERMINAL_APPLY_STARTED",
            response = response,
            state = currentState,
            stateAfter = response.callState,
            result = "applying",
            reason = "terminal_status_received"
        )
        deps.logging.logStatusResponse(
            "applyCallSessionStatus_terminal_before_update",
            response,
            appendNote,
            currentState,
            normalizedDialogue
        )
        deps.state.setPendingAiCallLaunch(false)
        val terminalPlan = callSessionTerminalDisplayPlan(
            response = response,
            existingHistoryStatus = currentState.callPageData.status,
            currentCallUiMode = currentState.callUiMode
        )
        deps.runtime.stopCallSessionPolling()
        deps.runtime.stopTakeoverAudioSocket()
        deps.state.setLastAppliedDialogueDetail(null)
        deps.runtime.clearTakeoverProtectWindow()
        deps.state.updateState {
            TaskReceiptUiStateReducer.applyCallSessionTerminalDisplay(it, terminalPlan)
        }
        deps.logging.logStatusResponse(
            "applyCallSessionStatus_terminal_after_update",
            response,
            appendNote,
            deps.state.currentState(),
            normalizedDialogue
        )
        logTerminal(
            eventType = "CALL_TERMINAL_APPLIED",
            response = response,
            state = deps.state.currentState(),
            stateAfter = response.callState,
            result = "applied",
            reason = "terminal_display_updated"
        )
    }

    private fun logTerminal(
        eventType: String,
        response: CallSessionStatusResponse,
        state: Index9AssistantUiState,
        stateAfter: String,
        result: String,
        reason: String
    ) {
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.CALL,
                eventType = eventType,
                sessionId = deps.state.agentSessionId(),
                taskId = response.taskId.takeIf { it.isNotBlank() } ?: state.taskId,
                callId = response.callId.takeIf { it.isNotBlank() } ?: state.currentCallId,
                stateBefore = state.callPageData.status,
                stateAfter = stateAfter,
                result = result,
                reason = reason,
                attributes = mapOf(
                    "callState" to response.callState,
                    "handoffMode" to response.handoffMode,
                    "resultCode" to response.resultCode
                )
            )
        )
    }
}
