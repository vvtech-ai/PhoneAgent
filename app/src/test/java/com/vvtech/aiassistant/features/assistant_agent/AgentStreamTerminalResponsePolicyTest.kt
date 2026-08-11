package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToClarificationStepsAdapter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamTerminalResponsePolicyTest {
    @Test
    fun callResultBuildsRecognizedStateAndClearsInteractiveVoiceFields() {
        val callResult = CallResultPayload(
            status = "COMPLETED",
            headline = "done",
            detail = "assistant: hello\ncallee: confirmed"
        )
        val state = dirtyTerminalState()
        val plan = AgentStreamTerminalResponsePolicy.callResult(
            AgentStreamTerminalResponseInput(
                state = state,
                response = AgentChatResponse(
                    sessionId = "response-session",
                    type = "CALL_RESULT",
                    text = null,
                    callResult = callResult
                ),
                statusText = "任务完成",
                conversationStatus = "COMPLETED",
                conversationSessionId = "current-session"
            )
        )

        val next = plan.nextState
        assertEquals("任务完成", plan.statusText)
        assertEquals("COMPLETED", plan.conversationStatus)
        assertEquals("current-session", plan.conversationSessionId)
        assertEquals(AssistantStage.Recognized, next.stage)
        assertFalse(next.processingTurn)
        assertFalse(next.loading)
        assertFalse(next.listening)
        assertFalse(next.voiceConnecting)
        assertFalse(next.voiceActive)
        assertFalse(next.voiceManuallyPaused)
        assertFalse(next.voiceBackgroundPaused)
        assertFalse(next.apiAsrListening)
        assertNull(next.apiAsrPartialText)
        assertFalse(next.apiTtsPlaying)
        assertFalse(next.localTtsSpeaking)
        assertNull(next.error)
        assertEquals("任务完成", next.status)
        assertEquals("COMPLETED", next.taskStatus)
        assertFalse(next.showAiCallPage)
        assertNull(next.currentCallId)
        assertNull(next.liveUserTranscript)
        assertNull(next.liveAssistantTranscript)
        assertEquals("任务完成", next.callPageData.status)
        assertTrue(next.callPageData.transcript.size > state.callPageData.transcript.size)
        assertEquals(callResult.status, next.agentCallResult?.status)
        assertEquals(callResult.headline, next.agentCallResult?.headline)
        assertEquals(callResult.detail, next.agentCallResult?.detail)
        assertEquals("tool-call:tool-old", next.agentCallResult?.metadata?.get("callAttemptId"))
        assertEquals(1, next.timelineItems.size)
        assertEquals("single:tool-call:tool-old", next.timelineItems.single().itemId)
        assertNull(next.agentCallSpec)
        assertNull(next.agentQuestions)
        assertNull(next.agentPermissionRequest)
        assertNull(next.agentDocumentRequest)
        assertFalse(next.agentDocumentImporting)
        assertNull(next.agentPendingToolCallId)
    }

    @Test
    fun batchCallResultBuildsRecognizedStateAndUsesSessionFallback() {
        val state = dirtyTerminalState().copy(
            voiceBackgroundPaused = true,
            agentCallResult = CallResultPayload("COMPLETED", "old", "old")
        )
        val plan = AgentStreamTerminalResponsePolicy.batchCallResult(
            AgentStreamTerminalResponseInput(
                state = state,
                response = AgentChatResponse(
                    sessionId = "response-session",
                    type = "BATCH_CALL_RESULT",
                    text = null,
                    batchCallResult = BatchCallResultPayload(
                        status = "FAILED",
                        headline = "partial",
                        items = listOf(
                            BatchCallItemResultPayload(
                                itemId = "1",
                                targetName = "A",
                                phoneNumber = "10086",
                                status = "FAILED",
                                headline = "failed",
                                detail = "no answer",
                                attemptCount = 1,
                                recalled = false,
                                abnormal = true
                            )
                        )
                    )
                ),
                statusText = "批量外呼已完成",
                conversationStatus = "INCOMPLETE",
                conversationSessionId = "response-session"
            )
        )

        val next = plan.nextState
        assertEquals("response-session", plan.conversationSessionId)
        assertEquals("INCOMPLETE", plan.conversationStatus)
        assertEquals(AssistantStage.Recognized, next.stage)
        assertFalse(next.processingTurn)
        assertFalse(next.loading)
        assertFalse(next.listening)
        assertFalse(next.voiceConnecting)
        assertFalse(next.voiceActive)
        assertFalse(next.voiceManuallyPaused)
        assertTrue(next.voiceBackgroundPaused)
        assertFalse(next.apiAsrListening)
        assertNull(next.apiAsrPartialText)
        assertFalse(next.apiTtsPlaying)
        assertFalse(next.localTtsSpeaking)
        assertNull(next.error)
        assertEquals("批量外呼已完成", next.status)
        assertEquals("INCOMPLETE", next.taskStatus)
        assertFalse(next.showAiCallPage)
        assertNull(next.currentCallId)
        assertNull(next.liveUserTranscript)
        assertNull(next.liveAssistantTranscript)
        assertNull(next.agentCallSpec)
        assertNull(next.agentCallResult)
        assertNull(next.agentQuestions)
        assertNull(next.agentPermissionRequest)
        assertNull(next.agentDocumentRequest)
        assertFalse(next.agentDocumentImporting)
        assertNull(next.agentPendingToolCallId)
        assertEquals(1, next.timelineItems.size)
        assertEquals("batch:tool-old", next.timelineItems.single().itemId)
    }

    @Test
    fun secondOnlineCallKeepsFirstReceiptAndItsNewTurnAfterImmediateRefresh() {
        val first = terminalCallResult(
            state = Index9AssistantUiState(taskId = "task-1", agentPendingToolCallId = "tool-first"),
            callId = "call-first",
            headline = "first"
        )
        val beforeSecondResult = first.nextState.copy(
            clarificationSteps = first.nextState.clarificationSteps + listOf(
                userStep("继续联系第二家"),
                assistantPlaceholder()
            ),
            agentPendingToolCallId = "tool-second"
        )

        val second = terminalCallResult(beforeSecondResult, callId = "call-second", headline = "second")

        assertEquals(
            listOf("single:call:call-first", "single:call:call-second"),
            second.nextState.timelineItems.map { it.itemId }
        )
        assertEquals(
            listOf("first", "继续联系第二家", "second"),
            second.nextState.clarificationSteps.map { step -> step.callResult?.headline ?: step.text }
        )
    }

    private fun terminalCallResult(
        state: Index9AssistantUiState,
        callId: String,
        headline: String
    ): AgentStreamTerminalResponsePlan = AgentStreamTerminalResponsePolicy.callResult(
        AgentStreamTerminalResponseInput(
            state = state,
            response = AgentChatResponse(
                sessionId = "session-1",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(
                    status = "COMPLETED",
                    headline = headline,
                    detail = "done",
                    metadata = mapOf("callId" to callId)
                )
            ),
            statusText = "任务完成",
            conversationStatus = "COMPLETED",
            conversationSessionId = "session-1"
        )
    )

    private fun userStep(text: String) = com.vvtech.aiassistant.features.assistant.ClarificationStep(
        role = VoiceRole.User,
        text = text,
        status = ""
    )

    private fun assistantPlaceholder() = com.vvtech.aiassistant.features.assistant.ClarificationStep(
        role = VoiceRole.Assistant,
        text = "",
        status = "",
        streaming = true
    )

    private fun dirtyTerminalState(): Index9AssistantUiState {
        return Index9AssistantUiState(
            stage = AssistantStage.Clarifying,
            processingTurn = true,
            loading = true,
            listening = true,
            voiceConnecting = true,
            voiceActive = true,
            voiceManuallyPaused = true,
            voiceBackgroundPaused = true,
            apiAsrListening = true,
            apiAsrPartialText = "partial",
            apiTtsPlaying = true,
            localTtsSpeaking = true,
            error = "old error",
            status = "old status",
            taskStatus = "RUNNING",
            showAiCallPage = true,
            currentCallId = "call-1",
            liveUserTranscript = "user live",
            liveAssistantTranscript = "assistant live",
            callPageData = CallPageData(
                name = "target",
                sub = "goal",
                status = "calling",
                transcript = listOf(TranscriptLine(TranscriptRole.Note, "existing note"))
            ),
            agentOptions = OptionsPayload("old options", listOf(OptionItem(id = "1", label = "one"))),
            agentQuestions = AskQuestionsPayload(
                title = "old questions",
                items = listOf(AskQuestionItem(id = "q1", prompt = "question", answerType = "text"))
            ),
            agentPermissionRequest = PermissionRequestPayload(permissionKey = "contacts"),
            agentDocumentRequest = DocumentImportRequestPayload(reason = "upload"),
            agentDocumentImporting = true,
            agentPendingToolCallId = "tool-old",
            agentCallSpec = CallSpecPayload(
                phoneNumber = "10086",
                scene = "general",
                targetName = "target",
                primaryGoal = "goal",
                summaryLines = emptyList()
            )
        )
    }
}
