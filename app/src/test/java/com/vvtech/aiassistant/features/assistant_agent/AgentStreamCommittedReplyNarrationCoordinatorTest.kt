package com.vvtech.aiassistant.features.assistant_agent

import com.google.gson.JsonObject
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.domain.task.BatchTaskReceiptState
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamCommittedReplyNarrationCoordinatorTest {
    @Test
    fun terminalThenCommittedProjectionNarratesTheExactWhiteReply() {
        val harness = Harness()
        val event = committedReply(text = SUCCESS_REPLY)

        harness.coordinator.onTaskResultApplied(callResult())
        harness.coordinator.onTimelineCommitted(event)
        harness.coordinator.onProjectionApplied(projection(event, SUCCESS_REPLY))

        assertEquals(listOf(SUCCESS_REPLY), harness.spoken)
    }

    @Test
    fun committedProjectionBeforeTerminalWaitsForAudioGateRelease() {
        val harness = Harness()
        val event = committedReply(text = FAILURE_REPLY)

        harness.coordinator.onTimelineCommitted(event)
        harness.coordinator.onProjectionApplied(projection(event, FAILURE_REPLY))
        assertTrue(harness.spoken.isEmpty())

        harness.coordinator.onTaskResultApplied(callResult(status = "FAILED"))

        assertEquals(listOf(FAILURE_REPLY), harness.spoken)
    }

    @Test
    fun duplicateTerminalAndCommittedEventsNarrateOnlyOnce() {
        val harness = Harness()
        val event = committedReply(text = SUCCESS_REPLY)
        val response = callResult()

        repeat(2) {
            harness.coordinator.onTaskResultApplied(response)
            harness.coordinator.onTimelineCommitted(event)
            harness.coordinator.onProjectionApplied(projection(event, SUCCESS_REPLY))
        }

        assertEquals(listOf(SUCCESS_REPLY), harness.spoken)
    }

    @Test
    fun batchCommittedReplyUsesTheDurableWhiteReplyInsteadOfReceiptContent() {
        val harness = Harness()
        val event = committedReply(
            text = "通知完成，需要重试未接通的联系人吗？",
            finishReason = "batch_call_result",
        )

        harness.coordinator.onTaskResultApplied(
            AgentChatResponse(
                sessionId = SESSION_ID,
                type = "BATCH_CALL_RESULT",
                text = "批量外呼完成：1 路成功，1 路未完成",
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "通知结果",
                    items = emptyList(),
                    batchId = "batch-1",
                ),
            )
        )
        harness.coordinator.onTimelineCommitted(event)
        harness.coordinator.onProjectionApplied(
            projection(event, "通知完成，需要重试未接通的联系人吗？")
        )

        assertEquals(listOf("通知完成，需要重试未接通的联系人吗？"), harness.spoken)
    }

    @Test
    fun normalAssistantTurnAndTextModeDoNotNarrate() {
        val voiceHarness = Harness()
        val normal = committedReply(text = "普通回复", finishReason = "stop")
        voiceHarness.coordinator.onTaskResultApplied(callResult())
        voiceHarness.coordinator.onTimelineCommitted(normal)
        voiceHarness.coordinator.onProjectionApplied(projection(normal, "普通回复"))
        assertTrue(voiceHarness.spoken.isEmpty())

        val textHarness = Harness(voiceMode = false)
        val taskReply = committedReply(text = SUCCESS_REPLY)
        textHarness.coordinator.onTaskResultApplied(callResult())
        textHarness.coordinator.onTimelineCommitted(taskReply)
        textHarness.coordinator.onProjectionApplied(projection(taskReply, SUCCESS_REPLY))
        assertTrue(textHarness.spoken.isEmpty())
    }

    @Test
    fun newTurnClearsAnUnmatchedTerminalBeforeTheNextCommittedReply() {
        val harness = Harness()
        harness.coordinator.onTaskResultApplied(callResult())
        harness.coordinator.onTurnStarted(SESSION_ID)

        val nextReply = committedReply(text = SUCCESS_REPLY, eventId = "event-2")
        harness.coordinator.onTimelineCommitted(nextReply)
        harness.coordinator.onProjectionApplied(projection(nextReply, SUCCESS_REPLY))
        assertTrue(harness.spoken.isEmpty())

        harness.coordinator.onTaskResultApplied(
            callResult().copy(
                callResult = callResult().callResult?.copy(
                    metadata = mapOf(
                        "callAttemptId" to "attempt-2",
                        "callId" to "call-2",
                    )
                )
            )
        )
        assertEquals(listOf(SUCCESS_REPLY), harness.spoken)
    }

    @Test
    fun syncedSnapshotCanRecoverACommittedMeetingReplyWithoutItsSseCallback() {
        val harness = Harness()
        val event = committedReply(
            text = "老王已确认，明天中午12点大会议室见。",
            eventId = "meeting-reply",
        )
        val projection = projection(event, "老王已确认，明天中午12点大会议室见.").copy(
            taskResultReplies = listOf(
                TimelineTaskResultReply(
                    eventId = event.eventId,
                    sessionId = SESSION_ID,
                    sequence = event.sequence,
                    text = "老王已确认，明天中午12点大会议室见。",
                    finishReason = "call_result",
                )
            )
        )

        harness.coordinator.onTaskResultApplied(callResult())
        harness.coordinator.onProjectionApplied(projection)

        assertEquals(listOf("老王已确认，明天中午12点大会议室见。"), harness.spoken)
    }

    @Test
    fun snapshotFallbackDoesNotNarrateAReplyFromBeforeTheCurrentCallResult() {
        val harness = Harness()
        val previousReply = committedReply(
            text = "上一通电话已完成。",
            eventId = "previous-reply",
        )
        val projection = projection(previousReply, "上一通电话已完成。").copy(
            timelineItems = projection(previousReply, "上一通电话已完成。").timelineItems.map {
                if (it.payload is ConversationTimelinePayload.SingleCallReceipt) {
                    it.copy(ledgerSequence = previousReply.sequence + 1)
                } else {
                    it
                }
            },
            taskResultReplies = listOf(
                TimelineTaskResultReply(
                    eventId = previousReply.eventId,
                    sessionId = SESSION_ID,
                    sequence = previousReply.sequence,
                    text = "上一通电话已完成。",
                    finishReason = "call_result",
                )
            ),
        )

        harness.coordinator.onTaskResultApplied(callResult())
        harness.coordinator.onProjectionApplied(projection)

        assertTrue(harness.spoken.isEmpty())
    }

    @Test
    fun syncedSnapshotCanRecoverABatchReplyWithoutItsSseCallback() {
        val harness = Harness()
        val reply = committedReply(
            text = "会议通知已经发完，两位都确认参加。",
            finishReason = "batch_call_result",
            eventId = "batch-reply",
        )
        val batchReceipt = ConversationTimelineItem(
            itemId = "batch-attempt-1",
            sessionId = SESSION_ID,
            orderKey = TimelineOrderKey(messageIndex = 0),
            payload = ConversationTimelinePayload.BatchCallReceipt(
                batchAttemptId = "batch-1",
                receipt = BatchTaskReceiptState(
                    batchId = "batch-1",
                    status = "COMPLETED",
                    headline = "通知完成",
                    items = listOf(
                        TaskReceiptItemState(
                            itemId = "item-1",
                            targetName = "老王",
                            status = "SUCCESS",
                        )
                    ),
                ),
            ),
            ledgerSequence = reply.sequence - 1,
        )
        val projection = projection(reply, reply.payload.get("text").asString).copy(
            timelineItems = listOf(
                batchReceipt,
                ConversationTimelineItem(
                    itemId = "assistant-${reply.eventId}",
                    sessionId = SESSION_ID,
                    orderKey = TimelineOrderKey(messageIndex = 1),
                    payload = ConversationTimelinePayload.AssistantMessage(
                        "会议通知已经发完，两位都确认参加。"
                    ),
                    ledgerSequence = reply.sequence,
                    ledgerEventId = reply.eventId,
                ),
            ),
            taskResultReplies = listOf(
                TimelineTaskResultReply(
                    eventId = reply.eventId,
                    sessionId = SESSION_ID,
                    sequence = reply.sequence,
                    text = "会议通知已经发完，两位都确认参加。",
                    finishReason = "batch_call_result",
                )
            ),
        )

        harness.coordinator.onTaskResultApplied(
            AgentChatResponse(
                sessionId = SESSION_ID,
                type = "BATCH_CALL_RESULT",
                text = "批量外呼完成",
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "通知完成",
                    items = emptyList(),
                    batchId = "batch-1",
                ),
            )
        )
        harness.coordinator.onProjectionApplied(projection)

        assertEquals(listOf("会议通知已经发完，两位都确认参加。"), harness.spoken)
    }

    private class Harness(voiceMode: Boolean = true) {
        val spoken = mutableListOf<String>()
        val coordinator = AgentStreamCommittedReplyNarrationCoordinator(
            isVoiceMode = { voiceMode },
            taskIdProvider = { SESSION_ID },
            maybeTtsSignal = spoken::add,
        )
    }

    private fun callResult(status: String = "COMPLETED") = AgentChatResponse(
        sessionId = SESSION_ID,
        type = "CALL_RESULT",
        text = "任务已完成",
        callResult = CallResultPayload(
            status = status,
            headline = "状态卡片标题",
            detail = "状态卡片详情",
            metadata = mapOf(
                "callAttemptId" to "attempt-1",
                "callId" to "call-1",
            ),
        ),
    )

    private fun committedReply(
        text: String,
        finishReason: String = "call_result",
        eventId: String = "event-1",
    ) = ConversationLedgerEvent(
        eventId = eventId,
        sessionId = SESSION_ID,
        sequence = 10,
        type = ConversationLedgerEventType.Known(
            StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED
        ),
        schemaVersion = 1,
        idempotencyKey = "key-$eventId",
        occurredAt = "2026-07-27T12:00:00Z",
        committedAt = "2026-07-27T12:00:00Z",
        payload = JsonObject().apply {
            addProperty("modelTurnId", "turn-$eventId")
            addProperty("text", text)
            addProperty("finishReason", finishReason)
        },
    )

    private fun projection(
        event: ConversationLedgerEvent,
        text: String,
    ): TimelineSnapshotUiProjection {
        val receipt = ConversationTimelineItem(
            itemId = "call-attempt-1",
            sessionId = SESSION_ID,
            orderKey = TimelineOrderKey(messageIndex = 0),
            payload = ConversationTimelinePayload.SingleCallReceipt(
                callAttemptId = "attempt-1",
                callId = "call-1",
                receipt = TaskReceiptItemState(
                    itemId = "attempt-1",
                    targetName = "target",
                    status = "COMPLETED",
                    headline = "completed",
                ),
            ),
            ledgerSequence = event.sequence - 1,
        )
        return TimelineSnapshotUiProjection(
            sessionId = SESSION_ID,
            timelineItems = listOf(
                receipt,
                ConversationTimelineItem(
                itemId = "assistant-${event.eventId}",
                sessionId = SESSION_ID,
                orderKey = TimelineOrderKey(messageIndex = 1),
                payload = ConversationTimelinePayload.AssistantMessage(text),
                ledgerSequence = event.sequence,
                ledgerEventId = event.eventId,
                )
            ),
            clarificationSteps = emptyList(),
            conversationStatus = "COMPLETED",
            conversationContinuable = true,
            pendingToolRestorable = false,
            latestSingleReceipt = receipt,
        )
    }

    private companion object {
        const val SESSION_ID = "session-1"
        const val SUCCESS_REPLY = "改好了！北海渔村明晚已改为10点。"
        const val FAILURE_REPLY = "北海渔村说明晚10点5位没位置了。"
    }
}
