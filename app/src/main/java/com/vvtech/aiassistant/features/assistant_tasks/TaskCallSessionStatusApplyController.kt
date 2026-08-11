package com.vvtech.aiassistant.features.assistant_tasks

import android.os.SystemClock
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

internal data class TaskCallSessionStatusApplyControllerDeps(
    val state: TaskCallSessionStatusApplyStateAccess,
    val runtime: TaskCallSessionStatusApplyRuntimeActions,
    val logging: TaskCallSessionStatusApplyLogging,
    val terminalStatusController: TaskCallSessionTerminalStatusController
)

internal data class TaskCallSessionStatusApplyStateAccess(
    val currentState: () -> Index9AssistantUiState,
    val updateState: (((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit),
    val lastAppliedDialogueDetail: () -> String?,
    val setLastAppliedDialogueDetail: (String?) -> Unit,
    val lastAppliedStatusAt: () -> LocalDateTime?,
    val setLastAppliedStatusAt: (LocalDateTime?) -> Unit,
    val activeTakeoverCallId: () -> String?,
    val takeoverStateProtectUntilElapsed: () -> Long,
    val agentSessionId: () -> String?,
    val pendingAiCallLaunch: () -> Boolean,
    val setPendingAiCallLaunch: (Boolean) -> Unit
)

internal data class TaskCallSessionStatusApplyRuntimeActions(
    val mergeTranscript: (List<TranscriptLine>, String?) -> List<TranscriptLine>,
    val logTranscript: (message: String, taskId: String) -> Unit,
    val ensureTakeoverAudioSocket: (taskId: String?, callId: String?) -> Unit,
    val stopTakeoverAudioSocket: () -> Unit
)

internal data class TaskCallSessionStatusApplyLogging(
    val internalLog: (String) -> Unit,
    val logStatusResponse: (
        reason: String,
        response: CallSessionStatusResponse,
        appendNote: Boolean,
        state: Index9AssistantUiState,
        normalizedDialogue: String
    ) -> Unit
)

internal class TaskCallSessionStatusApplyController(
    private val deps: TaskCallSessionStatusApplyControllerDeps
) {
    private val terminalStatusController = deps.terminalStatusController
    private var lastStructuredStatusKey: String? = null

    fun apply(
        response: CallSessionStatusResponse,
        appendNote: Boolean
    ) {
        val currentState = deps.state.currentState()
        val previousDialogue = deps.state.lastAppliedDialogueDetail()
        val normalizedDialogue = response.dialogueDetail.trim()
        logStatusChangeIfNeeded(response, currentState)
        deps.logging.logStatusResponse("applyCallSessionStatus_received", response, appendNote, currentState, normalizedDialogue)
        val rebuiltTranscript = deps.runtime.mergeTranscript(
            currentState.callPageData.transcript,
            response.dialogueDetail
        )
        if (normalizedDialogue.isNotBlank() && normalizedDialogue != previousDialogue) {
            deps.runtime.logTranscript(
                normalizedDialogue,
                response.taskId.ifBlank { currentState.taskId.orEmpty() }
            )
        }
        val responseUpdatedAt = parseTaskCallSessionUpdatedAt(response.updatedAt)
        val lastApplied = deps.state.lastAppliedStatusAt()
        if (responseUpdatedAt != null && lastApplied != null && responseUpdatedAt.isBefore(lastApplied)) {
            logStatusDecision(
                eventType = "CALL_STATUS_IGNORED",
                response = response,
                state = currentState,
                result = "ignored",
                reason = "stale_response"
            )
            deps.logging.internalLog(
                "ignore stale call status callId=${response.callId} handoff=${response.handoffMode} " +
                    "updatedAt=${response.updatedAt} lastApplied=${lastApplied.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)}"
            )
            deps.logging.logStatusResponse(
                "applyCallSessionStatus_ignore_stale",
                response,
                appendNote,
                currentState,
                normalizedDialogue
            )
            return
        }
        if (response.callState.equals("NOT_FOUND", ignoreCase = true) && deps.state.currentState().currentCallId.isNullOrBlank()) {
            logStatusDecision(
                eventType = "CALL_STATUS_IGNORED",
                response = response,
                state = currentState,
                result = "ignored",
                reason = "not_found_without_active_call"
            )
            deps.logging.logStatusResponse(
                "applyCallSessionStatus_ignore_not_found_no_current_call",
                response,
                appendNote,
                currentState,
                normalizedDialogue
            )
            return
        }
        val statusFacts = taskCallSessionStatusFacts(
            response = response,
            appendNote = appendNote,
            activeTakeoverCallId = deps.state.activeTakeoverCallId(),
            nowElapsedMillis = SystemClock.elapsedRealtime(),
            takeoverStateProtectUntilElapsed = deps.state.takeoverStateProtectUntilElapsed()
        )
        if (statusFacts.protectTakeoverState) {
            logStatusDecision(
                eventType = "CALL_STATUS_IGNORED",
                response = response,
                state = currentState,
                result = "protected",
                reason = "takeover_state_protected"
            )
            deps.logging.internalLog(
                "protect takeover state from regressive status callId=${response.callId} " +
                    "handoff=${response.handoffMode} updatedAt=${response.updatedAt}"
            )
            deps.logging.logStatusResponse(
                "applyCallSessionStatus_protect_takeover",
                response,
                appendNote,
                currentState,
                normalizedDialogue
            )
            markLastAppliedIfNewer(responseUpdatedAt, lastApplied)
            return
        }
        if (statusFacts.shouldStartTakeoverAudio) {
            deps.runtime.ensureTakeoverAudioSocket(response.taskId, response.callId)
        } else if (statusFacts.shouldStopTakeoverAudio) {
            deps.runtime.stopTakeoverAudioSocket()
        }

        deps.state.updateState { state ->
            TaskReceiptUiStateReducer.applyCallSessionNonTerminalDisplay(
                state = state,
                response = response,
                facts = statusFacts,
                rebuiltTranscript = rebuiltTranscript
            )
        }
        deps.logging.logStatusResponse(
            "applyCallSessionStatus_after_non_terminal_update terminal=${statusFacts.terminalCallState}",
            response,
            appendNote,
            deps.state.currentState(),
            normalizedDialogue
        )
        markLastAppliedIfNewer(responseUpdatedAt, lastApplied)

        val shouldDeferAgentOutcome = shouldDeferTaskCallSessionTerminalStatus(
            response = response,
            context = TaskCallSessionAgentOutcomeDeferContext(
                currentTaskId = currentState.taskId,
                agentSessionId = deps.state.agentSessionId(),
                hasAgentCallResult = currentState.agentCallResult != null,
                processingTurn = currentState.processingTurn,
                pendingAiCallLaunch = deps.state.pendingAiCallLaunch()
            )
        )
        if (statusFacts.terminalCallState && shouldDeferAgentOutcome) {
            terminalStatusController.applyDeferredAgentOutcome(
                response = response,
                appendNote = appendNote,
                currentState = currentState,
                normalizedDialogue = normalizedDialogue
            )
            return
        }
        if (statusFacts.terminalCallState) {
            terminalStatusController.applyTerminalStatus(response, currentState, appendNote, normalizedDialogue)
        }
    }

    private fun logStatusChangeIfNeeded(
        response: CallSessionStatusResponse,
        state: Index9AssistantUiState
    ) {
        val key = listOf(
            response.callId,
            response.callState,
            response.handoffMode,
            response.resultCode
        ).joinToString("|")
        if (key == lastStructuredStatusKey) return
        val previous = lastStructuredStatusKey
        lastStructuredStatusKey = key
        logStatusDecision(
            eventType = "CALL_STATUS_CHANGED",
            response = response,
            state = state,
            result = "applied",
            reason = "poll_status_changed",
            stateBefore = previous,
            stateAfter = key
        )
    }

    private fun logStatusDecision(
        eventType: String,
        response: CallSessionStatusResponse,
        state: Index9AssistantUiState,
        result: String,
        reason: String,
        stateBefore: String? = null,
        stateAfter: String? = null
    ) {
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.CALL,
                eventType = eventType,
                sessionId = deps.state.agentSessionId(),
                taskId = response.taskId.takeIf { it.isNotBlank() } ?: state.taskId,
                callId = response.callId.takeIf { it.isNotBlank() } ?: state.currentCallId,
                stateBefore = stateBefore,
                stateAfter = stateAfter ?: response.callState,
                result = result,
                reason = reason,
                attributes = mapOf(
                    "handoffMode" to response.handoffMode,
                    "resultCode" to response.resultCode,
                    "backendCallEnabled" to response.backendCallEnabled.toString()
                )
            )
        )
    }

    private fun markLastAppliedIfNewer(
        responseUpdatedAt: LocalDateTime?,
        lastApplied: LocalDateTime?
    ) {
        if (responseUpdatedAt != null && (lastApplied == null || responseUpdatedAt.isAfter(lastApplied))) {
            deps.state.setLastAppliedStatusAt(responseUpdatedAt)
        }
    }
}
