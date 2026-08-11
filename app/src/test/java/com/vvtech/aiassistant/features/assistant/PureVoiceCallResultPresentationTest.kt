package com.vvtech.aiassistant.features.assistant

import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.task.ReceiptField
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceCallResultPresentationTest {
    @Test
    fun structuredFailureUsesTheOriginalRedPresentationWithExactFields() {
        val fields = listOf(
            ReceiptField("taskType", "任务", "餐厅预订"),
            ReceiptField("restaurantName", "餐厅", "海底捞"),
            ReceiptField("partySize", "人数", "4 人"),
            ReceiptField("reservationTime", "时间", "今晚 8 点"),
        )
        val standardResult = CallResultPayload(
            status = "FAILED",
            headline = "海底捞今晚已满",
            detail = "餐厅无法完成预订",
            receiptFields = fields,
        )

        val plan = pureVoiceCallResultPresentation(
            sceneType = "RESTAURANT_BOOKING",
            summary = null,
            data = CallPageData(
                name = "海底捞",
                sub = "实时外呼",
                status = "FAILED",
                transcript = listOf(TranscriptLine(TranscriptRole.Note, "预订结果：满位")),
                callResult = standardResult,
            ),
        )

        assertTrue(plan.state.structuredReceipt)
        assertTrue(plan.state.failureResult)
        assertEquals("任务失败", plan.style.title)
        assertEquals(Color(0xFFC62828), plan.style.titleColor)
        assertEquals(listOf(Color(0xFFFFF1F0), Color(0xFFFFDAD6)), plan.style.gradient)
        assertEquals(fields.map { it.label to it.value }, plan.content.structuredRows)
    }

    @Test
    fun structuredSuccessUsesTheOriginalGreenPresentation() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "已确认明晚 8 点 4 人包间",
            detail = "预订成功",
            receiptFields = listOf(
                ReceiptField("taskType", "任务", "餐厅预订"),
                ReceiptField("restaurantName", "餐厅", "海底捞"),
                ReceiptField("partySize", "人数", "4 人"),
                ReceiptField("reservationTime", "时间", "今晚 8 点"),
            ),
        )

        val plan = pureVoiceCallResultPresentation(
            sceneType = "RESTAURANT_BOOKING",
            summary = null,
            data = CallPageData("海底捞", "实时外呼", "COMPLETED", emptyList(), result),
        )

        assertTrue(plan.state.structuredReceipt)
        assertFalse(plan.state.failureResult)
        assertEquals("任务完成", plan.style.title)
        assertEquals(Color(0xFF2E7D32), plan.style.titleColor)
        assertEquals(listOf(Color(0xFFEDFAF0), Color(0xFFD6F5DC)), plan.style.gradient)
    }

    @Test
    fun legacyFailureKeepsTheExistingReasonFallback() {
        val plan = pureVoiceCallResultPresentation(
            sceneType = "RESTAURANT_BOOKING",
            summary = null,
            data = CallPageData(
                name = "海底捞",
                sub = "实时外呼",
                status = "FAILED",
                transcript = listOf(TranscriptLine(TranscriptRole.Note, "预订结果：餐厅满位，预订失败")),
            ),
        )

        assertEquals("任务失败", plan.style.title)
        assertEquals("餐厅满位，预订失败", plan.content.failureReason)
        assertFalse(plan.state.structuredReceipt)
    }

    @Test
    fun meetingNotificationSuccessUsesExecutionResultAndObjectiveStatus() {
        val plan = pureVoiceCallResultPresentation(
            sceneType = "AI_CALL",
            summary = null,
            data = notificationCallPageData(
                status = "COMPLETED",
                headline = "会议通知已送达",
                agentOutcome = "SUCCESS",
                detail = "对方已收到会议通知",
            ),
        )

        assertEquals("执行结果", plan.style.title)
        assertEquals("已通知", plan.content.resultStatus)
        assertFalse(plan.state.bookingResult)
        assertFalse(plan.state.failureResult)
    }

    @Test
    fun unclearMeetingNotificationUsesSuccessPresentation() {
        val plan = pureVoiceCallResultPresentation(
            sceneType = "AI_CALL",
            summary = null,
            data = notificationCallPageData(
                status = "COMPLETED",
                headline = "会议通知已送达",
                agentOutcome = "UNCLEAR",
                detail = "对方已收到会议通知",
            ),
        )

        assertEquals("执行结果", plan.style.title)
        assertEquals("已通知", plan.content.resultStatus)
        assertEquals(Color(0xFF2E7D32), plan.style.titleColor)
        assertFalse(plan.state.bookingResult)
        assertFalse(plan.state.failureResult)
    }

    @Test
    fun parkingMoveSuccessUsesTheExactNotifiedTarget() {
        val statuses = mapOf(
            "挪车已通知车主" to "已通知车主",
            "挪车已通知物业" to "已通知物业",
            "挪车已通知保安" to "已通知保安",
            "挪车已通知停车场" to "已通知停车场",
            "挪车已通知公司前台" to "已通知公司前台",
            "挪车已通知114" to "已通知114",
            "挪车已通知122" to "已通知122",
        )

        statuses.forEach { (headline, status) ->
            val plan = pureVoiceCallResultPresentation(
                sceneType = "AI_CALL",
                summary = null,
                data = notificationCallPageData(
                    status = "COMPLETED",
                    headline = headline,
                    agentOutcome = "SUCCESS",
                ),
            )

            assertEquals("执行结果", plan.style.title)
            assertEquals(status, plan.content.resultStatus)
            assertFalse(plan.state.bookingResult)
            assertFalse(plan.state.failureResult)
        }
    }

    @Test
    fun notificationFailureUsesExecutionResultAndFailureStatus() {
        listOf("挪车通知失败", "会议通知失败").forEach { headline ->
            val plan = pureVoiceCallResultPresentation(
                sceneType = "AI_CALL",
                summary = null,
                data = notificationCallPageData(
                    status = "FAILED",
                    headline = headline,
                    agentOutcome = "FAILED",
                    detail = "电话未接通",
                ),
            )

            assertEquals("执行结果", plan.style.title)
            assertEquals("失败", plan.content.resultStatus)
            assertFalse(plan.state.bookingResult)
            assertTrue(plan.state.failureResult)
        }
    }

    @Test
    fun genericNotifiedHeadlineKeepsTheExistingPresentation() {
        val plan = pureVoiceCallResultPresentation(
            sceneType = "AI_CALL",
            summary = null,
            data = notificationCallPageData(
                status = "COMPLETED",
                headline = "已通知",
                agentOutcome = "SUCCESS",
            ),
        )

        assertEquals("任务完成", plan.style.title)
        assertEquals("完成", plan.content.resultStatus)
        assertTrue(plan.state.bookingResult)
        assertFalse(plan.state.failureResult)
    }

    private fun notificationCallPageData(
        status: String,
        headline: String,
        agentOutcome: String,
        detail: String = "",
    ): CallPageData {
        val result = CallResultPayload(
            status = status,
            headline = headline,
            detail = detail,
            metadata = mapOf("agentOutcome" to agentOutcome),
        )
        return CallPageData(
            name = "联系人",
            sub = "会议预约通知",
            status = status,
            transcript = listOf(TranscriptLine(TranscriptRole.Note, headline)),
            callResult = result,
        )
    }
}
