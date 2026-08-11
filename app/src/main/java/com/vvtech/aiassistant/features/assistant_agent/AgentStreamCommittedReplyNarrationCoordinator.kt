package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

/**
 * Joins the task terminal, durable assistant reply and applied UI projection before requesting TTS.
 * The durable assistant reply is the same source rendered by the final white message bubble.
 */
internal class AgentStreamCommittedReplyNarrationCoordinator(
    private val isVoiceMode: () -> Boolean,
    private val taskIdProvider: () -> String?,
    private val maybeTtsSignal: (String) -> Unit,
) {
    private data class PendingReply(
        val eventId: String,
        val sessionId: String,
        val text: String,
        val finishReason: String,
        val projected: Boolean = false,
    )

    private data class TerminalMarker(
        val key: String,
        val responseType: String,
        val callAttemptId: String?,
        val callId: String?,
        val batchId: String?,
    )

    private val pendingReplies = mutableMapOf<String, PendingReply>()
    private val terminalMarkers = mutableMapOf<String, TerminalMarker>()
    private val narratedEventIds = LinkedHashSet<String>()
    private val consumedTerminalKeys = LinkedHashSet<String>()

    fun onTurnStarted(sessionId: String) {
        pendingReplies.remove(sessionId)
        terminalMarkers.remove(sessionId)
    }

    fun onTimelineCommitted(event: ConversationLedgerEvent) {
        val reply = committedTaskReply(event) ?: return
        if (reply.eventId in narratedEventIds) return
        pendingReplies[reply.sessionId] = reply
    }

    fun onTaskResultApplied(response: AgentChatResponse) {
        if (response.type != TYPE_CALL_RESULT && response.type != TYPE_BATCH_CALL_RESULT) return
        val marker = terminalMarker(response)
        if (marker.key in consumedTerminalKeys) return
        terminalMarkers[response.sessionId] = marker
        maybeNarrate(response.sessionId)
    }

    fun onProjectionApplied(projection: TimelineSnapshotUiProjection) {
        val pending = pendingReplies[projection.sessionId]
        if (pending != null) {
            val containsReply = projection.timelineItems.any { item ->
                item.ledgerEventId == pending.eventId &&
                    item.payload is ConversationTimelinePayload.AssistantMessage
            }
            if (containsReply) {
                pendingReplies[projection.sessionId] = pending.copy(projected = true)
            }
        }
        val terminal = terminalMarkers[projection.sessionId]
        val terminalSequence = terminal?.let {
            projection.terminalReceiptSequence(
                responseType = it.responseType,
                callAttemptId = it.callAttemptId,
                batchId = it.batchId,
            )
        }
        if (terminalSequence != null) {
            projection.taskResultReplies
                .asReversed()
                .firstOrNull {
                    it.sequence > terminalSequence &&
                        it.finishReason == terminal.expectedFinishReason &&
                        it.eventId !in narratedEventIds
                }
                ?.let { reply ->
                    pendingReplies[projection.sessionId] = PendingReply(
                        eventId = reply.eventId,
                        sessionId = reply.sessionId,
                        text = reply.text,
                        finishReason = reply.finishReason,
                        projected = true,
                    )
                }
        }
        maybeNarrate(projection.sessionId)
    }

    private val TerminalMarker.expectedFinishReason: String
        get() = when (responseType) {
            TYPE_BATCH_CALL_RESULT -> "batch_call_result"
            else -> "call_result"
        }

    private fun maybeNarrate(sessionId: String) {
        val reply = pendingReplies[sessionId]?.takeIf { it.projected } ?: return
        val terminal = terminalMarkers[sessionId] ?: return
        pendingReplies.remove(sessionId)
        terminalMarkers.remove(sessionId)
        remember(narratedEventIds, reply.eventId)
        remember(consumedTerminalKeys, terminal.key)
        if (!isVoiceMode()) return

        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.TTS,
                eventType = "TASK_RESULT_NARRATION_REQUESTED",
                sessionId = sessionId,
                taskId = taskIdProvider(),
                callAttemptId = terminal.callAttemptId,
                callId = terminal.callId,
                result = terminal.responseType,
                reason = "committed_assistant_reply_projected",
                attributes = mapOf(
                    "eventId" to reply.eventId,
                    "finishReason" to reply.finishReason,
                    "textLength" to reply.text.length.toString(),
                ),
            )
        )
        maybeTtsSignal(reply.text)
    }

    private fun committedTaskReply(event: ConversationLedgerEvent): PendingReply? {
        val type = event.type as? ConversationLedgerEventType.Known ?: return null
        if (type.stable != StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED) return null
        val finishReason = event.payload.stringValue("finishReason").lowercase()
        if (finishReason !in TASK_RESULT_FINISH_REASONS) return null
        val text = event.payload.stringValue("text").takeIf(String::isNotBlank) ?: return null
        return PendingReply(
            eventId = event.eventId,
            sessionId = event.sessionId,
            text = text,
            finishReason = finishReason,
        )
    }

    private fun terminalMarker(response: AgentChatResponse): TerminalMarker {
        val callAttemptId = response.callResult?.metadata?.get("callAttemptId")
        val callId = response.callResult?.metadata?.get("callId")
        val batchId = response.batchCallResult?.batchId
        val identity = callAttemptId
            ?: callId
            ?: batchId
            ?: listOf(
                response.type,
                response.callResult?.status,
                response.batchCallResult?.status,
                response.text,
            ).joinToString("|")
        return TerminalMarker(
            key = "${response.sessionId}|${response.type}|$identity",
            responseType = response.type,
            callAttemptId = callAttemptId,
            callId = callId,
            batchId = batchId,
        )
    }

    private fun remember(values: LinkedHashSet<String>, value: String) {
        values += value
        while (values.size > MAX_REMEMBERED_IDENTITIES) {
            values.remove(values.first())
        }
    }

    private fun com.google.gson.JsonObject.stringValue(key: String): String {
        val value = get(key)?.takeUnless { it.isJsonNull } ?: return ""
        return runCatching { value.asString }.getOrDefault("").trim()
    }

    private companion object {
        const val TYPE_CALL_RESULT = "CALL_RESULT"
        const val TYPE_BATCH_CALL_RESULT = "BATCH_CALL_RESULT"
        const val MAX_REMEMBERED_IDENTITIES = 128
        val TASK_RESULT_FINISH_REASONS = setOf("call_result", "batch_call_result")
    }
}
