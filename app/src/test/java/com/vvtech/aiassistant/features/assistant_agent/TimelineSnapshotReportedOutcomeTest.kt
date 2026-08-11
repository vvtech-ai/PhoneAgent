package com.vvtech.aiassistant.features.assistant_agent

import com.google.gson.JsonObject
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.LedgerTimelineState
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TimelineSnapshotReportedOutcomeTest {
    @Test
    fun physicalTerminalDoesNotSatisfyReportedOutcomeUntilSemanticEventArrives() {
        val physical = event(
            sequence = 1,
            type = StableConversationLedgerEventType.CALL_COMPLETED,
            callId = "call-current",
        )
        val reported = event(
            sequence = 2,
            type = StableConversationLedgerEventType.CALL_OUTCOME_REPORTED,
            callId = null,
        )

        assertFalse(
            TimelineSnapshotUiProjector.project(snapshot(listOf(physical)))
                .hasReportedCallOutcomeForCallId("call-current")
        )
        assertTrue(
            TimelineSnapshotUiProjector.project(snapshot(listOf(physical, reported)))
                .hasReportedCallOutcomeForCallId("call-current")
        )
    }

    private fun snapshot(events: List<ConversationLedgerEvent>) = ConversationTimelineSnapshot(
        sessionId = "session-1",
        ledgerHeadSequence = events.maxOfOrNull(ConversationLedgerEvent::sequence) ?: 0L,
        events = events,
        projection = ConversationTimelineProjection(
            conversationStatus = "COMPLETED",
            conversationContinuable = false,
            pendingToolRestorable = false,
            migrationStatus = "MIGRATED",
            projectedThroughSequence = events.maxOfOrNull(ConversationLedgerEvent::sequence) ?: 0L,
        ),
        timeline = LedgerTimelineState(
            items = listOf(
                ConversationTimelineItem(
                    itemId = "ledger:call:attempt-1",
                    sessionId = "session-1",
                    taskId = "session-1",
                    orderKey = TimelineOrderKey(0),
                    payload = ConversationTimelinePayload.SingleCallReceipt(
                        callAttemptId = "attempt-1",
                        callId = "call-current",
                        receipt = TaskReceiptItemState(
                            itemId = "attempt-1",
                            targetName = "商家",
                            status = "COMPLETED",
                            headline = "电话已结束",
                            detail = "",
                        ),
                    ),
                    ledgerSequence = 1,
                    ledgerEventId = "event-1",
                )
            )
        ),
    )

    private fun event(
        sequence: Long,
        type: StableConversationLedgerEventType,
        callId: String?,
    ) = ConversationLedgerEvent(
        eventId = "event-$sequence",
        sessionId = "session-1",
        sequence = sequence,
        type = ConversationLedgerEventType.Known(type),
        schemaVersion = 1,
        idempotencyKey = "key-$sequence",
        occurredAt = "2026-07-25T00:00:00Z",
        committedAt = "2026-07-25T00:00:00Z",
        payload = JsonObject(),
        taskId = "session-1",
        callAttemptId = "attempt-1",
        callId = callId,
    )
}
