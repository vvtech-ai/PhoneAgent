package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

internal data class TaskCallSessionStatusFacts(
    val humanMode: Boolean,
    val humanRequested: Boolean,
    val terminalCallState: Boolean,
    val protectTakeoverState: Boolean,
    val note: String?,
    val shouldStartTakeoverAudio: Boolean,
    val shouldStopTakeoverAudio: Boolean
)

internal data class TaskCallSessionAgentOutcomeDeferContext(
    val currentTaskId: String?,
    val agentSessionId: String?,
    val hasAgentCallResult: Boolean,
    val processingTurn: Boolean,
    val pendingAiCallLaunch: Boolean
)

internal fun taskCallSessionStatusFacts(
    response: CallSessionStatusResponse,
    appendNote: Boolean,
    activeTakeoverCallId: String?,
    nowElapsedMillis: Long,
    takeoverStateProtectUntilElapsed: Long
): TaskCallSessionStatusFacts {
    val handoffMode = response.handoffMode.normalizedCallSessionValue()
    val callState = response.callState.normalizedCallSessionValue()
    val humanMode = handoffMode == "HUMAN_ACTIVE"
    val humanRequested = handoffMode == "HUMAN_REQUESTED"
    val connected = callState == "CONNECTED"
    val terminalCallState = taskCallSessionIsTerminalCallState(callState)
    val activeTakeover = !activeTakeoverCallId.isNullOrBlank()
    val protectTakeoverState = activeTakeover &&
        !humanMode &&
        !humanRequested &&
        connected &&
        nowElapsedMillis < takeoverStateProtectUntilElapsed
    return TaskCallSessionStatusFacts(
        humanMode = humanMode,
        humanRequested = humanRequested,
        terminalCallState = terminalCallState,
        protectTakeoverState = protectTakeoverState,
        note = taskCallSessionHandoffNote(response, appendNote),
        shouldStartTakeoverAudio = (humanMode || humanRequested) && connected,
        shouldStopTakeoverAudio = terminalCallState && activeTakeover
    )
}

internal fun shouldDeferTaskCallSessionTerminalStatus(
    response: CallSessionStatusResponse,
    context: TaskCallSessionAgentOutcomeDeferContext
): Boolean {
    val taskId = response.taskId.ifBlank { context.currentTaskId.orEmpty() }
    val agentSessionId = context.agentSessionId?.trim().orEmpty()
    if (taskId.isBlank() || agentSessionId.isBlank() || taskId != agentSessionId) {
        return false
    }
    if (context.hasAgentCallResult) {
        return false
    }
    val callState = response.callState.normalizedCallSessionValue()
    val handoffMode = response.handoffMode.normalizedCallSessionValue()
    val resultCode = response.resultCode.normalizedCallSessionValue()
    val agentOutcomeAlreadyRecorded = resultCode.startsWith("AGENT_")
    val transportReachedAgentOwnedTerminal =
        (callState == "ENDED" && handoffMode == "COMPLETED") ||
            (callState == "FAILED" && handoffMode == "FAILED")
    return transportReachedAgentOwnedTerminal && !agentOutcomeAlreadyRecorded
}

internal fun taskCallSessionIsTerminalCallState(callState: String): Boolean {
    return callState.normalizedCallSessionValue() in setOf("ENDED", "FAILED", "NOT_FOUND")
}

private fun taskCallSessionHandoffNote(
    response: CallSessionStatusResponse,
    appendNote: Boolean
): String? {
    if (!appendNote) return null
    val note = when (response.handoffMode.normalizedCallSessionValue()) {
        "HUMAN_ACTIVE" -> currentAppText("已切换为人工接管", "Switched to human takeover")
        "HUMAN_REQUESTED" -> currentAppText(
            "已收到人工接管请求，等待接管链路就绪",
            "Human takeover requested. Waiting for the connection to be ready"
        )
        "AI_RESUMING" -> currentAppText("正在切回 AI 代打", "Switching back to AI calling")
        "AI_ACTIVE" -> currentAppText("AI 代打继续处理中", "AI calling is still in progress")
        else -> response.statusMessage
    }
    return note.takeIf { it.isNotBlank() }
}

private fun String.normalizedCallSessionValue(): String = trim().uppercase(Locale.ROOT)
