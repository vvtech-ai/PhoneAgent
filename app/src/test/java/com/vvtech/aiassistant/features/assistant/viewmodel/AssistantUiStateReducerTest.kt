package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantUiStateReducerTest {
    @Test
    fun continuationOnlyClearsActiveWorkspaceAndKeepsTimelineUntouched() {
        val callResult = CallResultPayload(
            status = "COMPLETED",
            headline = "订餐成功",
            detail = "已预留包间"
        )
        val callPageData = CallPageData(
            name = "海底捞",
            sub = "订包间",
            status = "任务完成",
            transcript = listOf(
                TranscriptLine(TranscriptRole.Assistant, "今晚还有包房吗"),
                TranscriptLine(TranscriptRole.Remote, "可以预留")
            )
        )
        val state = Index9AssistantUiState(
            taskStatus = "COMPLETED",
            callUiMode = CallUiMode.Human,
            currentCallId = "call-1",
            handoffInFlight = true,
            callPageData = callPageData,
            showAiCallPage = true,
            agentCallResult = callResult,
            clarificationSteps = listOf(
                com.vvtech.aiassistant.features.assistant.ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "old receipt",
                    status = "COMPLETED"
                )
            ),
            timelineItems = listOf(
                ConversationTimelineItem(
                    itemId = "receipt:call-1",
                    orderKey = TimelineOrderKey(1),
                    payload = ConversationTimelinePayload.SingleCallReceipt(
                        callAttemptId = "call:1",
                        receipt = TaskReceiptItemState("call-1", "海底捞", "COMPLETED")
                    )
                )
            )
        )

        val updated = AssistantUiStateReducer.clearCallResultUiForContinuation(state)

        assertEquals("COMPLETED", updated.taskStatus)
        assertEquals(CallUiMode.Ai, updated.callUiMode)
        assertEquals(null, updated.currentCallId)
        assertFalse(updated.handoffInFlight)
        assertFalse(updated.showAiCallPage)
        assertSame(callPageData, updated.callPageData)
        assertNull(updated.agentCallResult)
        assertTrue(updated.callPageData.transcript.isNotEmpty())
        assertEquals(state.clarificationSteps, updated.clarificationSteps)
        assertEquals(state.timelineItems, updated.timelineItems)
    }
}
