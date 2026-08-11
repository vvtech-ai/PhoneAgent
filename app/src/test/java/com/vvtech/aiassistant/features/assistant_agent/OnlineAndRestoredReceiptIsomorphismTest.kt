package com.vvtech.aiassistant.features.assistant_agent

import com.google.gson.Gson
import com.google.gson.JsonParser
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.domain.task.ReceiptField
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_timeline.ConversationLedgerTimelineReducer
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import org.junit.Assert.assertEquals
import org.junit.Test

class OnlineAndRestoredReceiptIsomorphismTest {
    private val fields = listOf(
        ReceiptField("taskType", "任务", "餐厅预订"),
        ReceiptField("restaurantName", "餐厅", "海底捞"),
        ReceiptField("partySize", "人数", "4 人"),
        ReceiptField("reservationTime", "时间", "今晚 8 点"),
    )

    @Test
    fun successOnlineAndRestoredReceiptsAreIsomorphic() {
        assertIsomorphic("SUCCESS", "COMPLETED")
    }

    @Test
    fun userCancelledOnlineAndRestoredReceiptsAreIsomorphic() {
        assertIsomorphic("USER_CANCELLED", "CANCELLED")
    }

    @Test
    fun needsRecallOnlineAndRestoredReceiptsAreIsomorphic() {
        assertIsomorphic("NEEDS_RECALL", "FAILED")
    }

    private fun assertIsomorphic(semanticOutcome: String, transportStatus: String) {
        val headline = "结果-$semanticOutcome"
        val onlineState = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(),
            responseSessionId = "session-$semanticOutcome",
            callResult = CallResultPayload(
                status = transportStatus,
                headline = headline,
                detail = "reason",
                receiptFields = fields,
            ),
            toolCallId = "attempt-$semanticOutcome",
        )
        val online = (onlineState.timelineItems.single().payload as
            ConversationTimelinePayload.SingleCallReceipt).receipt

        val requested = event(
            sequence = 1L,
            type = StableConversationLedgerEventType.CALL_REQUESTED,
            semanticOutcome = semanticOutcome,
            payload = """{"recipientRef":"restaurant"}""",
        )
        val reported = event(
            sequence = 2L,
            type = StableConversationLedgerEventType.CALL_OUTCOME_REPORTED,
            semanticOutcome = semanticOutcome,
            payload = Gson().toJson(
                mapOf(
                    "outcome" to semanticOutcome,
                    "headline" to headline,
                    "reason" to "reason",
                    "receiptFields" to fields,
                )
            ),
        )
        val restored = (ConversationLedgerTimelineReducer.reduceAll(listOf(requested, reported))
            .items.single().payload as ConversationTimelinePayload.SingleCallReceipt).receipt

        assertEquals(online.status, restored.status)
        assertEquals(online.headline, restored.headline)
        assertEquals(online.receiptFields, restored.receiptFields)
    }

    private fun event(
        sequence: Long,
        type: StableConversationLedgerEventType,
        semanticOutcome: String,
        payload: String,
    ) = ConversationLedgerEvent(
        eventId = "event-$semanticOutcome-$sequence",
        sessionId = "session-$semanticOutcome",
        sequence = sequence,
        type = ConversationLedgerEventType.Known(type),
        schemaVersion = 1,
        idempotencyKey = "key-$semanticOutcome-$sequence",
        occurredAt = "2026-07-22T00:00:00Z",
        committedAt = "2026-07-22T00:00:01Z",
        payload = JsonParser().parse(payload).asJsonObject,
        callAttemptId = "attempt-$semanticOutcome",
    )
}
