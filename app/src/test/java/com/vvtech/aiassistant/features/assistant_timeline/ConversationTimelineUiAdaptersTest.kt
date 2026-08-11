package com.vvtech.aiassistant.features.assistant_timeline

import com.vvtech.aiassistant.domain.task.BatchTaskReceiptState
import com.vvtech.aiassistant.domain.task.ReceiptField
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationTimelineUiAdaptersTest {
    @Test
    fun clarificationProjectionPreservesTimelineOrderAndEveryReceipt() {
        val fields = listOf(
            ReceiptField("taskType", "任务", "餐厅预订"),
            ReceiptField("restaurantName", "餐厅", "海底捞"),
            ReceiptField("partySize", "人数", "4 人"),
            ReceiptField("reservationTime", "时间", "今晚 8 点"),
        )
        val items = listOf(
            item(4, "batch", ConversationTimelinePayload.BatchCallReceipt(
                batchAttemptId = "batch:1",
                receipt = BatchTaskReceiptState(
                    status = "COMPLETED",
                    headline = "批量完成",
                    items = listOf(TaskReceiptItemState("batch-item", "张三", "SUCCESS"))
                )
            )),
            item(1, "user", ConversationTimelinePayload.UserMessage("帮我联系两人")),
            item(3, "single", ConversationTimelinePayload.SingleCallReceipt(
                callAttemptId = "call:1",
                callId = "physical-call-1",
                receipt = TaskReceiptItemState(
                    itemId = "receipt-1",
                    targetName = "海底捞",
                    status = "COMPLETED",
                    headline = "已订好",
                    detail = "今晚八点",
                    transcript = "AI：还有包间吗？\n对方：可以。",
                    receiptFields = fields,
                )
            ))
        )

        val steps = ConversationTimelineToClarificationStepsAdapter.adapt(items)

        assertEquals("帮我联系两人", steps[0].text)
        assertEquals("已订好", steps[1].callResult?.headline)
        assertEquals("批量完成", steps[2].batchCallResult?.headline)
        assertEquals("call:1", steps[1].callResult?.metadata?.get("callAttemptId"))
        assertEquals("physical-call-1", steps[1].callResult?.metadata?.get("callId"))
        assertEquals(fields, steps[1].callResult?.receiptFields)
    }

    @Test
    fun callPageProjectionIsLatestCompatibilityValueNotHistorySource() {
        val fields = listOf(
            ReceiptField("taskType", "任务", "餐厅预订"),
            ReceiptField("parking", "停车", "商场 B2"),
        )
        val items = listOf(
            item(1, "first", receipt("first", "第一家", "第一条")),
            item(5, "second", receipt("second", "第二家", "第二条", fields, "第二条标题"))
        )
        val fallback = CallPageData("AI 助理", "实时外呼", "等待发起", emptyList())

        val page = ConversationTimelineToCallPageDataAdapter.adaptLatestSingleReceipt(items, fallback)

        assertEquals("第二家", page.name)
        assertEquals("COMPLETED", page.status)
        assertEquals(fields, page.receiptFields)
        assertEquals("第二条标题", page.callResult?.headline)
        assertEquals("第二条", page.callResult?.detail)
        assertEquals("physical-second", page.callResult?.metadata?.get("callId"))
        assertEquals(fields, page.callResult?.receiptFields)
        assertTrue(page.transcript.any { it.text == "第二条" })
        assertNotNull(ConversationTimelineToClarificationStepsAdapter.adapt(items)[0].callResult)
        assertNotNull(ConversationTimelineToClarificationStepsAdapter.adapt(items)[1].callResult)
    }

    @Test
    fun callPageProjectionPreservesLiveTranscriptWhenTerminalReceiptIsShorter() {
        val liveTranscript = listOf(
            TranscriptLine(TranscriptRole.Remote, "请问还有什么可以帮您？"),
            TranscriptLine(TranscriptRole.Assistant, "没有了，谢谢。"),
            TranscriptLine(TranscriptRole.Remote, "请问还有什么可以帮您？"),
            TranscriptLine(TranscriptRole.Assistant, "没有了，谢谢。"),
        )
        val terminalReceipt = item(
            1,
            "terminal",
            ConversationTimelinePayload.SingleCallReceipt(
                callAttemptId = "call:terminal",
                receipt = TaskReceiptItemState(
                    itemId = "terminal",
                    targetName = "客服",
                    status = "COMPLETED",
                    headline = "通话已结束",
                    transcript = "callee: 请问还有什么可以帮您？\n" +
                        "assistant: 没有了，谢谢。\n" +
                        "merchant: 祝您生活愉快。\n" +
                        "assistant: 好的，再见。",
                )
            )
        )
        val fallback = CallPageData(
            name = "客服",
            sub = "10000",
            status = "通话中",
            transcript = liveTranscript,
        )

        val page = ConversationTimelineToCallPageDataAdapter.adaptLatestSingleReceipt(
            listOf(terminalReceipt),
            fallback,
            preserveFallbackTranscript = true,
        )

        assertEquals(liveTranscript, page.transcript.take(liveTranscript.size))
        assertTrue(page.transcript.any {
            it.role == TranscriptRole.Assistant && it.text == "好的，再见。"
        })
        assertTrue(page.transcript.any {
            it.role == TranscriptRole.Remote && it.text == "祝您生活愉快。"
        })
        assertTrue(page.transcript.any {
            it.role == TranscriptRole.Note && it.text == "通话已结束"
        })
    }

    @Test
    fun durableSequenceWinsOverPlaceholderOrderKeyAndItemId() {
        val items = listOf(
            item(0, "ledger:z", ConversationTimelinePayload.UserMessage("先说"))
                .copy(ledgerSequence = 1),
            item(0, "ledger:a", ConversationTimelinePayload.AssistantMessage("后答"))
                .copy(ledgerSequence = 2),
        )

        val steps = ConversationTimelineToClarificationStepsAdapter.adapt(items)

        assertEquals(listOf("先说", "后答"), steps.map { it.text })
    }

    private fun receipt(
        id: String,
        target: String,
        detail: String,
        fields: List<ReceiptField> = emptyList(),
        headline: String = "",
    ) =
        ConversationTimelinePayload.SingleCallReceipt(
            callAttemptId = "call:$id",
            callId = "physical-$id",
            receipt = TaskReceiptItemState(
                id,
                target,
                "COMPLETED",
                headline = headline,
                detail = detail,
                receiptFields = fields,
            )
        )

    private fun item(
        messageIndex: Int,
        id: String,
        payload: ConversationTimelinePayload
    ) = ConversationTimelineItem(
        itemId = id,
        orderKey = TimelineOrderKey(messageIndex),
        payload = payload
    )
}
