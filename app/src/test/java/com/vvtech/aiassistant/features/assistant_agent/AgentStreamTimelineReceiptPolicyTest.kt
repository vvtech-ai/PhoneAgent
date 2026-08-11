package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.task.ReceiptField
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUiStateReducer
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamTimelineReceiptPolicyTest {
    @Test
    fun singleReceiptKeepsAssistantExplanationAlreadyRenderedForCurrentTurn() {
        val explanation = "对方连续拒接，可能暂时不方便接听，建议稍后再试。"
        val updated = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(
                clarificationSteps = listOf(
                    ClarificationStep(
                        role = VoiceRole.Assistant,
                        text = explanation,
                        status = "",
                    )
                )
            ),
            responseSessionId = "session-failed",
            callResult = CallResultPayload(
                status = "FAILED",
                headline = "电话持续被拒接",
                detail = "对方拒绝了这通电话。",
                metadata = mapOf("callId" to "call-failed"),
            ),
            toolCallId = "tool-failed",
        )

        assertEquals(explanation, updated.clarificationSteps.single().text)
        assertEquals("FAILED", updated.clarificationSteps.single().callResult?.status)
    }

    @Test
    fun onlineReceiptUsesTheSameFieldsForTimelineCardsAndCallPage() {
        val fields = listOf(
            ReceiptField("taskType", "任务", "餐厅预订"),
            ReceiptField("restaurantName", "餐厅", "海底捞"),
            ReceiptField("reservationTime", "时间", "今晚 8 点"),
        )

        val updated = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(),
            responseSessionId = "session-1",
            callResult = CallResultPayload(
                status = "COMPLETED",
                headline = "预订成功",
                detail = "legacy detail",
                metadata = mapOf(
                    "targetName" to "海底捞",
                    "callId" to "provider-call-1",
                    "callAttemptId" to "attempt-1",
                ),
                receiptFields = fields,
            ),
            toolCallId = "tool-1",
        )

        val timelineReceipt = (updated.timelineItems.single().payload as
            ConversationTimelinePayload.SingleCallReceipt).receipt
        assertEquals(fields, timelineReceipt.receiptFields)
        assertEquals(fields, updated.agentCallResult?.receiptFields)
        assertEquals(fields, updated.callPageData.receiptFields)
        assertEquals(updated.agentCallResult, updated.callPageData.callResult)
        assertEquals(
            "provider-call-1",
            (updated.timelineItems.single().payload as
                ConversationTimelinePayload.SingleCallReceipt).callId,
        )
        assertEquals("provider-call-1", updated.agentCallResult?.metadata?.get("callId"))

        val continued = AssistantUiStateReducer.clearCallResultUiForContinuation(updated)
        assertNull(continued.agentCallResult)
        assertEquals(fields, continued.callPageData.receiptFields)
        assertEquals(fields, (continued.timelineItems.single().payload as
            ConversationTimelinePayload.SingleCallReceipt).receipt.receiptFields)
    }

    @Test
    fun oldOnlineReceiptKeepsLegacyEmptyFields() {
        val updated = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(),
            responseSessionId = "session-legacy",
            callResult = CallResultPayload("COMPLETED", "完成", "旧详情"),
            toolCallId = null,
        )

        assertTrue(updated.agentCallResult?.receiptFields.orEmpty().isEmpty())
        assertTrue(updated.callPageData.receiptFields.isEmpty())
    }

    @Test
    fun nonStructuredOtherSceneKeepsItsOriginalTransportStatus() {
        val updated = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = Index9AssistantUiState(),
            responseSessionId = "session-other",
            callResult = CallResultPayload("PARTIAL", "已完成部分通知", "还有一人未接听"),
            toolCallId = null,
        )

        val receipt = (updated.timelineItems.single().payload as
            ConversationTimelinePayload.SingleCallReceipt).receipt
        assertEquals("PARTIAL", receipt.status)
    }

    @Test
    fun explicitBatchReceiptRemovesAlreadyProjectedSinglesFromTheSameBatchOnly() {
        val batchId = "batch-1"
        val unrelated = singleReceipt("single-attempt", "single-task", 0)
        val batchSingles = (1..3).map { index ->
            singleReceipt("batch-attempt-$index", batchId, index)
        }
        val state = Index9AssistantUiState(
            taskId = "session-1",
            timelineItems = listOf(unrelated) + batchSingles,
            clarificationSteps = (listOf(unrelated) + batchSingles).map(::singleStep),
        )

        val updated = AgentStreamTimelineReceiptPolicy.upsertBatchReceipt(
            state = state,
            responseSessionId = "session-1",
            result = BatchCallResultPayload(
                status = "COMPLETED",
                headline = "多路完成",
                items = batchSingles.mapIndexed { index, _ ->
                    BatchCallItemResultPayload(
                        itemId = "item-$index",
                        targetName = "联系人$index",
                        phoneNumber = "",
                        status = "SUCCESS",
                        headline = "完成",
                        detail = "",
                        attemptCount = 1,
                        recalled = false,
                        abnormal = false,
                        transcript = "转写$index",
                    )
                },
            ),
            batchAttemptId = batchId,
            stepIndex = state.clarificationSteps.lastIndex,
        )

        assertEquals(2, updated.timelineItems.size)
        assertEquals(2, updated.clarificationSteps.size)
        assertEquals("single-attempt", updated.clarificationSteps.first().callResult?.metadata?.get("callAttemptId"))
        assertNotNull(updated.clarificationSteps.last().batchCallResult)
    }

    private fun singleReceipt(attemptId: String, taskId: String, index: Int) = ConversationTimelineItem(
        itemId = "single:$attemptId",
        sessionId = "session-1",
        taskId = taskId,
        orderKey = TimelineOrderKey(index),
        payload = ConversationTimelinePayload.SingleCallReceipt(
            callAttemptId = attemptId,
            receipt = TaskReceiptItemState(
                itemId = attemptId,
                targetName = attemptId,
                status = "COMPLETED",
                headline = "完成",
                detail = "转写",
                transcript = "转写",
            ),
        ),
    )

    private fun singleStep(item: ConversationTimelineItem): ClarificationStep {
        val payload = item.payload as ConversationTimelinePayload.SingleCallReceipt
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = "",
            status = payload.receipt.status,
            callResult = CallResultPayload(
                status = payload.receipt.status,
                headline = payload.receipt.headline,
                detail = payload.receipt.detail,
                metadata = mapOf("callAttemptId" to payload.callAttemptId),
            ),
        )
    }
}
