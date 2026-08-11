package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal data class AgentStreamEventSessionGateCallbacks(
    val currentSessionId: () -> String?,
    val currentState: () -> Index9AssistantUiState,
    val hasActiveBatchCallStream: () -> Boolean,
    val clearActiveBatchCallState: () -> Unit,
)

internal class AgentStreamEventSessionGate(
    private val callbacks: AgentStreamEventSessionGateCallbacks,
) {
    private var lastIgnoredContext: String? = null

    fun shouldApply(streamSessionId: String, event: AgentStreamEvent): Boolean {
        val streamSession = streamSessionId.normalizedSessionId()
        val currentSession = callbacks.currentSessionId().normalizedSessionId()
        if (streamSession != null && streamSession == currentSession) {
            lastIgnoredContext = null
            return true
        }

        releaseDetachedBatchIfTerminal(event)
        val ignoredContext = "${streamSession.orEmpty()}|${currentSession.orEmpty()}"
        if (lastIgnoredContext != ignoredContext) {
            logIgnoredEvent(streamSession, currentSession, event)
            lastIgnoredContext = ignoredContext
        }
        return false
    }

    private fun releaseDetachedBatchIfTerminal(event: AgentStreamEvent) {
        if (!callbacks.hasActiveBatchCallStream()) return
        val responseType = event.responsePayload()?.type
        val terminal = responseType == TYPE_BATCH_CALL_RESULT ||
            responseType == TYPE_ERROR ||
            event is AgentStreamEvent.Err ||
            event === AgentStreamEvent.Done
        if (terminal) {
            callbacks.clearActiveBatchCallState()
        }
    }

    private fun logIgnoredEvent(
        streamSessionId: String?,
        currentSessionId: String?,
        event: AgentStreamEvent,
    ) {
        val response = event.responsePayload()
        val batchId = when (event) {
            is AgentStreamEvent.StatusDelta -> event.batchId
            else -> response?.batchCallResult?.batchId
        }
        val state = callbacks.currentState()
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = "AGENT_STREAM_EVENT_IGNORED",
                sessionId = streamSessionId,
                taskId = state.taskId,
                callAttemptId = response?.callResult?.metadata?.get("callAttemptId"),
                callId = response?.callResult?.metadata?.get("callId"),
                result = "ignored",
                reason = when {
                    streamSessionId == null -> "missing_stream_session"
                    currentSessionId == null -> "no_active_session"
                    else -> "session_mismatch"
                },
                attributes = mapOf(
                    "currentSessionId" to currentSessionId.orEmpty(),
                    "streamEventType" to event::class.simpleName.orEmpty(),
                    "responseType" to response?.type.orEmpty(),
                    "responseSessionId" to response?.sessionId.orEmpty(),
                    "batchId" to batchId.orEmpty(),
                ),
            )
        )
    }
}

private fun AgentStreamEvent.responsePayload(): AgentChatResponse? = when (this) {
    is AgentStreamEvent.Signal -> payload
    is AgentStreamEvent.Final -> payload
    else -> null
}

private fun String?.normalizedSessionId(): String? =
    this?.trim()?.takeIf(String::isNotEmpty)

private const val TYPE_BATCH_CALL_RESULT = "BATCH_CALL_RESULT"
private const val TYPE_ERROR = "ERROR"
