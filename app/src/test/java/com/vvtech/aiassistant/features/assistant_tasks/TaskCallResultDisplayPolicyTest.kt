package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.StatusStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallResultDisplayPolicyTest {
    @Test
    fun agentOutcomeSuccessOverridesTransportStatus() {
        val result = CallResultPayload(
            status = "未完成",
            headline = "AI 电话已结束",
            detail = successfulRestaurantCallDetail(),
            metadata = mapOf("agentOutcome" to "SUCCESS")
        )

        assertEquals(CallDisplayOutcome.Completed, callResultOutcome(result))
        assertEquals("COMPLETED", callResultTaskStatus(result))
        assertEquals("任务完成", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun remoteHangupMapsToIncomplete() {
        val result = CallResultPayload(
            status = "FAILED",
            headline = "对方已挂断",
            detail = "对方在任务完成前结束通话",
            metadata = mapOf("terminationCause" to "REMOTE_BYE")
        )

        assertEquals(CallDisplayOutcome.Failed, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
        assertEquals("未完成", callResultStatusText(result, "FOOD_ORDERING"))
        assertTrue(shouldClearCallResultForContinuation("COMPLETED", result))
    }

    @Test
    fun cancelledStatusMapsToIncomplete() {
        val result = CallResultPayload(
            status = "USER_CANCELLED",
            headline = "user cancelled",
            detail = "",
            metadata = mapOf("agentOutcome" to "USER_CANCELLED")
        )

        assertEquals(CallDisplayOutcome.Cancelled, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
        assertEquals("未完成", callResultStatusText(result, "FOOD_ORDERING"))
        assertEquals("未完成", callPageResultStatusFromSource("CANCELLED", "", "FOOD_ORDERING"))
    }

    @Test
    fun genericAiCallDoesNotPromoteTransportCompletionToBusinessSuccess() {
        val source = "AI：那可以帮我预订吗？\n对方：可以，有包房。"

        assertTrue(callDisplayIsBookingScene("AI_CALL", source))
        assertEquals("结果未确认", callPageResultStatusFromSource("COMPLETED", source, "AI_CALL"))
        assertFalse(callDisplayIsBookingScene("AI_CALL", "AI：请通知他明天十点开会。"))
    }

    @Test
    fun genericAiCallSuccessStatusHidesAiCallPrefix() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "已通知",
            detail = "老王确认下午六点开会",
            metadata = mapOf("agentOutcome" to "SUCCESS")
        )
        val source = "AI：请通知老王下午六点开会。\n对方：收到。"

        assertEquals("完成", callResultStatusText(result, "AI_CALL"))
        assertEquals("结果未确认", callPageResultStatusFromSource("COMPLETED", source, "AI_CALL"))
    }

    @Test
    fun resultCodeSuccessConfirmedIsTrustedWhenOutcomeMissing() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "订餐预约已确认",
            detail = successfulRestaurantCallDetail(),
            metadata = mapOf("resultCode" to "SUCCESS_CONFIRMED")
        )

        assertEquals(CallDisplayOutcome.Completed, callResultOutcome(result))
        assertEquals("任务完成", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun unclearSemanticOutcomeIsIncompleteEvenWhenTransportCompleted() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "通话已结束",
            detail = "对方没有确认预订结果",
            metadata = mapOf("agentOutcome" to "UNCLEAR")
        )

        assertEquals(CallDisplayOutcome.Unclear, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
        assertEquals("结果未确认", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun incompleteOrUnclearSessionResultIsNotPromotedToCompleted() {
        val decision = callSessionDisplayDecision(
            callSessionResponse(
                callState = "ENDED",
                handoffMode = "COMPLETED",
                resultCode = "INCOMPLETE_OR_UNCLEAR"
            )
        )

        assertEquals(CallDisplayOutcome.Unclear, decision.outcome)
        assertEquals("INCOMPLETE", decision.taskStatus)
        assertEquals("结果未确认", decision.statusText)
        assertEquals("结果未确认", decision.historyStatus)
    }

    @Test
    fun transportCompletionWithoutSemanticOutcomeStaysUnclear() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "AI 电话已结束",
            detail = "电话已正常接通并挂断",
            metadata = mapOf("callId" to "call-1")
        )

        assertEquals(CallDisplayOutcome.Unclear, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
        assertEquals("结果未确认", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun nullCallResultDoesNotClearContinuation() {
        assertFalse(shouldClearCallResultForContinuation("FAILED", null))
    }

    @Test
    fun completedCallResultClearsBeforeContinuation() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "订餐预约已确认",
            detail = successfulRestaurantCallDetail(),
            metadata = mapOf("agentOutcome" to "SUCCESS")
        )

        assertTrue(shouldClearCallResultForContinuation("COMPLETED", result))
        assertTrue(shouldClearCallResultForContinuation("ACTIVE", result))
    }

    @Test
    fun sessionDisplayDecisionKeepsBookingSuccessText() {
        val decision = callSessionDisplayDecision(
            CallSessionStatusResponse(
                callId = "call-1",
                taskId = "task-1",
                sceneType = "FOOD_ORDERING",
                targetName = "北海渔村",
                phoneNumber = "0755-86966889",
                callState = "ENDED",
                handoffMode = "COMPLETED",
                backendCallEnabled = true,
                handoffSupported = true,
                appRtcRequired = false,
                dialogueDetail = successfulRestaurantCallDetail(),
                statusMessage = "通话已结束",
                resultCode = "SUCCESS_CONFIRMED",
                updatedAt = "2026-05-12T05:40:52Z"
            )
        )

        assertEquals(CallDisplayOutcome.Completed, decision.outcome)
        assertEquals("COMPLETED", decision.taskStatus)
        assertEquals("任务完成", decision.statusText)
        assertEquals("任务完成", decision.historyStatus)
        assertEquals(StatusStyle.Success, decision.historyStyle)
    }

    @Test
    fun terminalDisplayPlanKeepsHumanTakeoverOverride() {
        val plan = callSessionTerminalDisplayPlan(
            response = callSessionResponse(
                callState = "FAILED",
                handoffMode = "FAILED",
                resultCode = "CALL_FAILED"
            ),
            existingHistoryStatus = "人工接管",
            currentCallUiMode = CallUiMode.Ai
        )

        assertEquals("人工接管", plan.historyStatus)
        assertEquals(StatusStyle.Success, plan.historyStyle)
        assertEquals("COMPLETED", plan.taskStatus)
        assertEquals("人工接管", plan.statusText)
    }

    @Test
    fun terminalDisplayPlanUsesFailedDecisionWhenNoHumanTakeover() {
        val plan = callSessionTerminalDisplayPlan(
            response = callSessionResponse(
                callState = "FAILED",
                handoffMode = "FAILED",
                resultCode = "CALL_FAILED",
                statusMessage = "商家未接通"
            ),
            existingHistoryStatus = null,
            currentCallUiMode = CallUiMode.Ai
        )

        assertEquals("未完成", plan.historyStatus)
        assertEquals(StatusStyle.Failure, plan.historyStyle)
        assertEquals("INCOMPLETE", plan.taskStatus)
        assertEquals("未完成", plan.statusText)
    }

    @Test
    fun networkTimeoutStillMapsToExecutionError() {
        val result = CallResultPayload(
            status = "FAILED",
            headline = "通话异常结束",
            detail = "网络连接超时",
            metadata = mapOf("terminationCause" to "TIMEOUT")
        )

        assertEquals("EXECUTION_ERROR", callResultTaskStatus(result))
        assertEquals("执行异常", callResultStatusText(result, "FOOD_ORDERING"))
    }

    @Test
    fun explicitNoAnswerStaysIncompleteEvenWhenTransportDetailContainsTimeoutNoise() {
        val result = CallResultPayload(
            status = "FAILED",
            headline = "无人接听",
            detail = "SIP polling timeout after the remote side did not answer",
            metadata = mapOf(
                "resultCode" to "NO_ANSWER",
                "resultReason" to "SIP_ERROR: invite timeout"
            )
        )

        assertEquals(CallDisplayOutcome.Failed, callResultOutcome(result))
        assertEquals("INCOMPLETE", callResultTaskStatus(result))
        assertEquals("未完成", callResultStatusText(result, "FOOD_ORDERING"))
    }

    private fun successfulRestaurantCallDetail(): String {
        return """
            assistant: 你好，是北海渔村吗？
            callee: 嗯，是的。
            assistant: 今晚还有包间吗？
            callee: 嗯，有的。
            assistant: 两个人用，大概六点到。
            callee: 好的。
            assistant: 手机号是18823189131。
            callee: 嗯，罗先生，尾号 9131。
        """.trimIndent()
    }

    private fun callSessionResponse(
        callState: String,
        handoffMode: String,
        resultCode: String,
        statusMessage: String = "通话已结束"
    ): CallSessionStatusResponse {
        return CallSessionStatusResponse(
            callId = "call-1",
            taskId = "task-1",
            sceneType = "FOOD_ORDERING",
            targetName = "北海渔村",
            phoneNumber = "0755-86966889",
            callState = callState,
            handoffMode = handoffMode,
            backendCallEnabled = true,
            handoffSupported = true,
            appRtcRequired = false,
            dialogueDetail = successfulRestaurantCallDetail(),
            statusMessage = statusMessage,
            resultCode = resultCode,
            updatedAt = "2026-05-12T05:40:52"
        )
    }
}
