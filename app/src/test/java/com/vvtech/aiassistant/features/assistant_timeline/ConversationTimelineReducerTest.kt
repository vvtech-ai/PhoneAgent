package com.vvtech.aiassistant.features.assistant_timeline

import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationTimelineReducerTest {
    @Test
    fun upsertKeepsOriginalPositionAndSortsNewItemsByOrderKey() {
        val first = message(id = "assistant-1", index = 2, text = "first")
        val receipt = receipt(id = "receipt-1", index = 3, status = "CALLING")
        val before = ConversationTimelineReducer.reduceAll(
            emptyList(),
            listOf(ConversationTimelineEvent.Upsert(receipt), ConversationTimelineEvent.Upsert(first))
        )

        val updated = ConversationTimelineReducer.reduce(
            before,
            ConversationTimelineEvent.Upsert(receipt.copy(payload = singleReceipt("attempt-1", "SUCCESS")))
        )

        assertEquals(listOf("assistant-1", "receipt-1"), updated.map { it.itemId })
        assertEquals("SUCCESS", (updated[1].payload as ConversationTimelinePayload.SingleCallReceipt).receipt.status)
        assertEquals("timeline:receipt-1", updated[1].stableUiKey)
    }

    @Test
    fun receiptPayloadReusesTaskReceiptOutcomeAndTerminalContract() {
        val item = receipt(id = "receipt-1", index = 1, status = "MISSED_CALL")
        val payload = item.payload as ConversationTimelinePayload.SingleCallReceipt

        assertTrue(payload.receipt.isTerminal)
        assertTrue(payload.receipt.needsAttention)
    }

    @Test
    fun removeOnlyDeletesMatchingItemId() {
        val state = listOf(message("user-1", 1, "hello"), message("assistant-1", 2, "hi"))

        val updated = ConversationTimelineReducer.reduce(state, ConversationTimelineEvent.Remove("user-1"))

        assertEquals(listOf("assistant-1"), updated.map { it.itemId })
    }

    private fun message(id: String, index: Int, text: String) = ConversationTimelineItem(
        itemId = id,
        orderKey = TimelineOrderKey(index),
        payload = ConversationTimelinePayload.AssistantMessage(text)
    )

    private fun receipt(id: String, index: Int, status: String) = ConversationTimelineItem(
        itemId = id,
        orderKey = TimelineOrderKey(index, 1),
        payload = singleReceipt("attempt-1", status)
    )

    private fun singleReceipt(attemptId: String, status: String) = ConversationTimelinePayload.SingleCallReceipt(
        callAttemptId = attemptId,
        receipt = TaskReceiptItemState(itemId = attemptId, targetName = "target", status = status)
    )
}
