package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import org.junit.Assert.assertEquals
import org.junit.Test

class PureVoiceConversationReceiptOrderTest {
    @Test
    fun restoredSingleReceiptBeforeNarrativeProjectsAsAiThenReceipt() {
        val receipt = CallResultPayload(
            status = "COMPLETED",
            headline = "预订成功",
            detail = "已预订今晚八点四人位",
            metadata = mapOf("callAttemptId" to "attempt-1"),
        )

        val projected = PureVoiceConversationStepProjector.project(
            listOf(
                user("帮我订餐"),
                assistant(callResult = receipt),
                assistant(text = "已经帮你订好了。"),
            )
        )

        assertEquals(2, projected.size)
        assertEquals("已经帮你订好了。", projected[1].text)
        assertEquals(receipt, projected[1].callResult)
    }

    @Test
    fun restoredFailedReceiptBeforeNarrativeProjectsAsAiThenReceipt() {
        val receipt = CallResultPayload(
            status = "FAILED",
            headline = "任务未完成",
            detail = "商家无人接听",
            metadata = mapOf("callAttemptId" to "attempt-2"),
        )

        val projected = PureVoiceConversationStepProjector.project(
            listOf(
                user("帮我联系商家"),
                assistant(callResult = receipt),
                assistant(text = "商家暂时没有接听，我没有替你确认预订。"),
            )
        )

        assertEquals(2, projected.size)
        assertEquals("商家暂时没有接听，我没有替你确认预订。", projected[1].text)
        assertEquals(receipt, projected[1].callResult)
    }

    @Test
    fun restoredBatchReceiptBeforeNarrativeProjectsAsAiThenReceipt() {
        val receipt = BatchCallResultPayload(
            status = "COMPLETED",
            headline = "通知完成",
            items = listOf(
                BatchCallItemResultPayload(
                    itemId = "item-1",
                    targetName = "张三",
                    phoneNumber = "",
                    status = "COMPLETED",
                    headline = "已通知",
                    detail = "对方已确认参会",
                    attemptCount = 1,
                    recalled = false,
                    abnormal = false,
                )
            ),
        )

        val projected = PureVoiceConversationStepProjector.project(
            listOf(
                user("通知参会人"),
                assistant(batchCallResult = receipt),
                assistant(text = "参会人已经全部通知完成。"),
            )
        )

        assertEquals(2, projected.size)
        assertEquals("参会人已经全部通知完成。", projected[1].text)
        assertEquals(receipt, projected[1].batchCallResult)
    }

    private fun user(text: String) = ClarificationStep(
        role = VoiceRole.User,
        text = text,
        status = "",
    )

    private fun assistant(
        text: String = "",
        callResult: CallResultPayload? = null,
        batchCallResult: BatchCallResultPayload? = null,
    ) = ClarificationStep(
        role = VoiceRole.Assistant,
        text = text,
        status = "",
        callResult = callResult,
        batchCallResult = batchCallResult,
    )
}
