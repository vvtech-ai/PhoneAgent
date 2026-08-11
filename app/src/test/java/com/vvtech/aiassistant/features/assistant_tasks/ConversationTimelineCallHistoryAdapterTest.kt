package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.util.TimeZone

class ConversationTimelineCallHistoryAdapterTest {
    @Test fun keepsFourAttemptsForOneTask() {
        val items = (1L..4L).map { sequence -> ConversationTimelineItem(
            itemId = "event-$sequence", sessionId = "task-1", taskId = "task-1", ledgerSequence = sequence,
            orderKey = TimelineOrderKey(0), payload = ConversationTimelinePayload.SingleCallReceipt(
                "attempt-$sequence", TaskReceiptItemState("attempt-$sequence", targetName = "目标", status = "CALL_COMPLETED")
            )
        ) }
        val records = ConversationTimelineCallHistoryAdapter.adapt(items)
        assertEquals(listOf("attempt-4", "attempt-3", "attempt-2", "attempt-1"), records.map { it.callAttemptId })
        assertEquals(4, records.map { it.key }.toSet().size)
    }

    @Test fun omitsPendingAttemptAndMapsTranscriptOnTerminalAttempt() {
        val pending = timelineItem(1L, "pending", "CALL_REQUESTED")
        val completed = timelineItem(
            2L,
            "completed",
            "COMPLETED",
            transcript = "assistant: 您好\nmerchant: 你好",
        )

        val records = ConversationTimelineCallHistoryAdapter.adapt(listOf(pending, completed))

        assertEquals(listOf("completed"), records.map { it.callAttemptId })
        assertTrue(records.first().finalState)
        assertEquals(2, records.first().transcript.size)
        assertEquals(com.vvtech.aiassistant.features.assistant.TranscriptRole.Remote, records.first().transcript.last().role)
    }

    @Test fun parsesOffsetTimestampWithoutAddingAnotherEightHours() {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"))

            val parsed = ConversationTimelineCallHistoryAdapter.run {
                "2026-07-21T15:30:00+08:00".toHistoryDateTime()
            }

            assertEquals(LocalDateTime.of(2026, 7, 21, 15, 30), parsed)
        } finally {
            TimeZone.setDefault(original)
        }
    }

    @Test fun keepsLegacyTimestampAsLocalWallClock() {
        val parsed = ConversationTimelineCallHistoryAdapter.run {
            "2026-07-21T15:30:00".toHistoryDateTime()
        }

        assertEquals(LocalDateTime.of(2026, 7, 21, 15, 30), parsed)
    }

    @Test fun keepsLegacyEndedAttemptAsTerminalHistory() {
        val records = ConversationTimelineCallHistoryAdapter.adapt(
            listOf(timelineItem(1L, "legacy-ended", "ENDED")),
        )

        assertEquals(listOf("legacy-ended"), records.map { it.callAttemptId })
        assertTrue(records.single().finalState)
    }

    private fun timelineItem(
        sequence: Long,
        attemptId: String,
        status: String,
        transcript: String? = null,
    ) = ConversationTimelineItem(
        itemId = "event-$sequence",
        sessionId = "session-1",
        taskId = "task-1",
        ledgerSequence = sequence,
        orderKey = TimelineOrderKey(0),
        payload = ConversationTimelinePayload.SingleCallReceipt(
            attemptId,
            TaskReceiptItemState(
                itemId = attemptId,
                targetName = "目标",
                status = status,
                transcript = transcript,
            ),
        ),
    )
}
