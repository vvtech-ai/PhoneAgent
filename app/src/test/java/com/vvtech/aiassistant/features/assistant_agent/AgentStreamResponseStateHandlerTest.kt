package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamResponseStateHandlerTest {
    @Test
    fun textReplyFlushesTtsAndUpdatesState() {
        val harness = Harness(state = Index9AssistantUiState(processingTurn = true))

        harness.handler.apply(AgentChatResponse(sessionId = "s1", type = "TEXT_REPLY", text = "ok"))

        assertTrue(harness.events.contains("ttsFlush"))
        assertTrue(harness.events.contains("confirm:agent_response_TEXT_REPLY:true"))
        assertEquals("AI已回复", harness.state.status)
        assertFalse(harness.state.processingTurn)
    }

    @Test
    fun makeCallRequestUpdatesSeedAndSchedulesAutoConfirm() {
        val harness = Harness(
            state = Index9AssistantUiState(sceneType = "GENERAL"),
            latestSeed = CallPageData(
                name = "旧目标",
                sub = "旧目标",
                status = "等待",
                transcript = emptyList()
            )
        )

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "s1",
                type = "MAKE_CALL_REQUEST",
                text = null,
                callSpec = CallSpecPayload(
                    phoneNumber = "10086",
                    scene = "FOOD_ORDERING",
                    targetName = "北海渔村",
                    primaryGoal = "订包间",
                    summaryLines = listOf("包间")
                ),
                pendingToolCallId = "tool-1"
            )
        )

        assertEquals("北海渔村", harness.latestSeed.name)
        assertEquals("订包间", harness.latestSeed.sub)
        assertEquals("FOOD_ORDERING", harness.state.sceneType)
        assertNotNull(harness.state.agentCallSpec)
        assertEquals("tool-1", harness.state.agentPendingToolCallId)
        assertTrue(harness.events.contains("scheduleAutoConfirm"))
    }

    @Test
    fun callResultLogsDiagnosticsAndUsesTerminalSideEffects() {
        val harness = Harness(
            state = Index9AssistantUiState(status = "old"),
            sessionId = "current-session"
        )

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(status = "COMPLETED", headline = "完成", detail = "已完成")
            )
        )

        assertTrue(harness.events.contains("logCallResult:current-session:COMPLETED"))
        assertFalse(harness.events.any { it.startsWith("history:") })
        assertTrue(harness.events.contains("clearPrimary"))
        assertTrue(harness.events.contains("clearPending"))
        assertEquals("任务完成", harness.state.status)
        assertEquals(listOf("COMPLETED", "RUNNING"), harness.conversations.map { it.status })
    }

    @Test
    fun callResultDelegatesCommittedReplyNarrationAfterTerminalStateIsApplied() {
        val harness = Harness(
            state = Index9AssistantUiState(status = "正在确认通话结果"),
            voiceMode = true
        )

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "CALL_RESULT",
                text = "这家没有包房，要换一家吗？",
                callResult = CallResultPayload(
                    status = "FAILED",
                    headline = "包房已满",
                    detail = "无法预订",
                    metadata = mapOf("agentOutcome" to "FAILED")
                )
            )
        )

        assertFalse(harness.events.any { it.startsWith("ttsSignal:") })
        assertTrue(harness.events.contains("taskResultApplied:CALL_RESULT"))
        assertTrue(
            harness.events.indexOf("applyState") <
                harness.events.indexOf("taskResultApplied:CALL_RESULT")
        )
    }

    @Test
    fun callResultMetadataDoesNotCreateSyntheticDurableHistory() {
        val harness = Harness(
            state = Index9AssistantUiState(
                callPageData = CallPageData(
                    name = "海底捞",
                    sub = "订包间",
                    status = "AI通话中",
                    transcript = emptyList()
                )
            ),
            sessionId = "current-session"
        )

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(
                    status = "COMPLETED",
                    headline = "完成",
                    detail = "已完成",
                    metadata = mapOf(
                        "callId" to "call-1",
                        "dialogueTranscript" to "assistant: 你好\nmerchant: 已订好"
                    )
                )
            )
        )

        assertTrue(harness.state.historyRecords.isEmpty())
        assertEquals("任务完成", harness.state.status)
    }

    @Test
    fun callResultDoesNotCreateSyntheticDurableHistory() {
        val harness = Harness(
            state = Index9AssistantUiState(
                callPageData = CallPageData(
                    name = "海底捞",
                    sub = "020-83196602",
                    status = "正在确认通话结果",
                    transcript = emptyList()
                ),
                historyRecords = emptyList()
            ),
            sessionId = "current-session"
        )

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(
                    status = "COMPLETED",
                    headline = "完成",
                    detail = "已完成",
                    metadata = mapOf(
                        "callId" to "call-1",
                        "dialogueTranscript" to "assistant: 你好\nmerchant: 已订好"
                    )
                )
            )
        )

        assertTrue(harness.state.historyRecords.isEmpty())
        assertFalse(harness.events.any { it.startsWith("history:") })
    }

    @Test
    fun batchCallResultClearsActiveBatchAndDoesNotClearPrimarySummary() {
        val harness = Harness(sessionId = null)

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "BATCH_CALL_RESULT",
                text = null,
                batchCallResult = null
            )
        )

        assertTrue(harness.events.contains("clearBatch"))
        assertTrue(harness.events.contains("clearPending"))
        assertFalse(harness.events.contains("clearPrimary"))
        assertFalse(harness.events.any { it.startsWith("batchHistory:") })
        assertEquals("任务已完成", harness.state.status)
        assertEquals(listOf("COMPLETED", "RUNNING"), harness.conversations.map { it.status })
    }

    @Test
    fun batchCallResultDelegatesCommittedReplyNarrationAfterTerminalStateIsApplied() {
        val harness = Harness(voiceMode = true, batchId = "active-batch")

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "BATCH_CALL_RESULT",
                text = "批量通知结束",
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "通知结果",
                    items = listOf(
                        batchItem(
                            itemId = "person-1",
                            targetName = "张三",
                            phoneNumber = "13800138000",
                            status = "SUCCESS",
                            headline = "已确认",
                            detail = "确认参加"
                        ),
                        batchItem(
                            itemId = "person-2",
                            targetName = "李四",
                            phoneNumber = "13900139000",
                            status = "FAILED",
                            headline = "未接通",
                            detail = "对方未接听"
                        )
                    )
                )
            )
        )

        assertFalse(harness.events.any { it.startsWith("ttsSignal:") })
        assertTrue(harness.events.contains("taskResultApplied:BATCH_CALL_RESULT"))
        assertTrue(
            harness.events.indexOf("applyState") <
                harness.events.indexOf("taskResultApplied:BATCH_CALL_RESULT")
        )
    }

    @Test
    fun batchCallResultKeepsReceiptInTransientUiWithoutSyntheticHistoryWrites() {
        val harness = Harness(sessionId = "parent-session", batchId = "active-batch")

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "response-session",
                type = "BATCH_CALL_RESULT",
                text = null,
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "批量外呼完成",
                    items = listOf(
                        batchItem(
                            itemId = "person-1",
                            targetName = "老九",
                            phoneNumber = "13800138000",
                            status = "SUCCESS",
                            headline = "对方已确认参加",
                            detail = "老九确认参加",
                            transcript = "assistant: 明天下午三点开会\ncallee: 好的，我会参加"
                        ),
                        batchItem(
                            itemId = "person-2",
                            targetName = "小米",
                            phoneNumber = "13800138001",
                            status = "SUCCESS",
                            headline = "对方已确认参加",
                            detail = "小米确认参加",
                            transcript = "assistant: 明天下午三点开会\ncallee: 没问题"
                        )
                    )
                )
            )
        )

        assertFalse(harness.events.any { it.startsWith("batchHistory:") })
        assertEquals("任务已完成", harness.state.status)
        assertEquals("batch:active-batch", harness.state.timelineItems.single().itemId)
    }

    @Test
    fun voiceErrorMarksRecoveryAndResumesListening() {
        val harness = Harness(
            state = Index9AssistantUiState(agentDocumentImporting = true),
            voiceMode = true
        )

        harness.handler.apply(AgentChatResponse(sessionId = "s1", type = "ERROR", text = "temporary failure"))

        assertTrue(harness.events.contains("markRecovery:EXECUTION_ERROR"))
        assertTrue(harness.events.contains("resumeListening:agent_error_recovery"))
        assertFalse(harness.state.agentDocumentImporting)
        assertNull(harness.state.error)
    }

    @Test
    fun unknownVoiceResponseUsesDistinctRecoveryTrigger() {
        val harness = Harness(
            state = Index9AssistantUiState(),
            voiceMode = true
        )

        harness.handler.apply(AgentChatResponse(sessionId = "s1", type = "NEW_TYPE", text = null))

        assertTrue(harness.events.contains("resumeListening:agent_unknown_response_recovery"))
    }

    @Test
    fun askUserVoiceReplacesGenericAssistantBubbleWithPrompt() {
        val harness = Harness(
            state = Index9AssistantUiState(
                clarificationSteps = listOf(
                    ClarificationStep(
                        role = VoiceRole.Assistant,
                        text = "需要你补充信息",
                        status = "",
                        toolCards = listOf(
                            ToolCardInfo(
                                toolName = "askUser",
                                methodLabel = "askUser()",
                                body = "q1: \"几位用餐\"",
                                result = "等待用户补充 1 项信息"
                            )
                        )
                    )
                ),
                processingTurn = true
            ),
            voiceMode = true
        )

        harness.handler.apply(
            AgentChatResponse(
                sessionId = "s1",
                type = "ASK_USER",
                text = "需要你补充信息",
                questions = AskQuestionsPayload(
                    title = "确认用餐信息",
                    items = listOf(
                        AskQuestionItem(
                            id = "people",
                            prompt = "9妮8点、10位包间，确认打给海底捞吗？",
                            answerType = "text"
                        )
                    )
                ),
                pendingToolCallId = "tool-ask"
            )
        )

        assertTrue(harness.events.contains("ttsSignal:9妮8点、10位包间，确认打给海底捞吗？"))
        assertEquals(1, harness.state.clarificationSteps.size)
        assertEquals(
            "确认用餐信息\n· 9妮8点、10位包间，确认打给海底捞吗？",
            harness.state.clarificationSteps.single().text
        )
        assertEquals("请语音回答", harness.state.status)
        assertEquals("tool-ask", harness.state.agentPendingToolCallId)
    }

    @Test
    fun unknownNonVoiceResponseLogsAndSetsExecutionError() {
        val harness = Harness(voiceMode = false)

        harness.handler.apply(AgentChatResponse(sessionId = "s1", type = "NEW_TYPE", text = null))

        assertTrue(harness.events.contains("log:handleAgentResponse unknown type=NEW_TYPE"))
        assertEquals("出错了", harness.state.status)
        assertEquals(AgentStreamSimpleResponseStatePolicy.unknownErrorText("NEW_TYPE"), harness.state.error)
    }

    @Test
    fun agentStreamHandlerDelegatesResponseStateDispatcher() {
        val handler =
            listOf(
                File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt"),
                File("android/app/src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
            ).first { it.exists() }.readText(Charsets.UTF_8)
        val responseGraph =
            listOf(
                File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseRuntimeGraph.kt"),
                File("android/app/src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseRuntimeGraph.kt")
            ).first { it.exists() }.readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamResponseRuntimeGraph("))
        assertTrue(handler.contains("responseRuntimeGraph.apply(response)"))
        assertTrue(responseGraph.contains("AgentStreamResponseStateHandler"))
        assertTrue(responseGraph.contains("responseStateHandler.apply(response)"))
        assertFalse(handler.contains("when (response.type)"))
        assertFalse(handler.contains("AgentStreamLookupRequestStateReducer.contactLookupRequest"))
    }

    private class Harness(
        var state: Index9AssistantUiState = Index9AssistantUiState(),
        var latestSeed: CallPageData = CallPageData(
            name = "AI",
            sub = "目标",
            status = "等待",
            transcript = emptyList()
        ),
        var sessionId: String? = "current-session",
        private val voiceMode: Boolean = false,
        batchId: String = "",
    ) {
        val events = mutableListOf<String>()
        private var activeBatchId = batchId
        var conversations = listOf(
            ConversationListItem(sessionId = sessionId ?: "response-session", title = "one", status = "RUNNING"),
            ConversationListItem(sessionId = "other", title = "two", status = "RUNNING")
        )

        val handler = AgentStreamResponseStateHandler(
            runtime = AgentStreamResponseRuntimeCallbacks(
                stateProvider = { state },
                updateState = { reducer -> state = reducer(state) },
                latestCallPageSeedProvider = { latestSeed },
                setLatestCallPageSeed = { latestSeed = it },
                scheduleAutoAgentCallConfirm = { events += "scheduleAutoConfirm" },
                internalLog = { events += "log:$it" },
                markTaskErrorRecoveryConfirmed = { reason, promote ->
                    events += "confirm:$reason:$promote"
                }
            ),
            voice = AgentStreamResponseVoiceCallbacks(
                isVoiceMode = { voiceMode },
                currentVoiceLanguage = { VoiceLanguage.Chinese },
                maybeTtsFlush = { events += "ttsFlush" },
                maybeTtsSignal = { events += "ttsSignal:$it" },
                appendAssistantStep = { events += "appendAssistant:$it" },
                markTaskErrorRecoveryInProgress = { events += "markRecovery:$it" },
                resumeListeningAfterAgentRecovery = { trigger ->
                    events += "resumeListening:$trigger"
                }
            ),
            terminal = AgentStreamResponseTerminalCallbacks(
                agentSessionIdProvider = { sessionId },
                callResultStatusText = { _, _ -> "任务完成" },
                callResultTaskStatus = { "COMPLETED" },
                logApplyCallResult = {
                    events += "logCallResult:${it.currentSessionId}:${it.resolvedConversationStatus}"
                },
                currentBatchIdProvider = { activeBatchId },
                clearActiveBatchCallState = {
                    events += "clearBatch"
                    activeBatchId = ""
                },
                terminalSideEffectHandler = AgentStreamTerminalSideEffectHandler(
                    clearPrimarySummaryAction = { events += "clearPrimary" },
                    clearPendingAiCallLaunch = { events += "clearPending" },
                    stopCallSessionPolling = { events += "stopPolling" },
                    stopApiListening = { events += "stopListening" },
                    applyUiState = {
                        state = it
                        events += "applyState"
                    },
                    conversationListProvider = { conversations },
                    setConversationList = { conversations = it },
                    loadConversations = { events += "loadConversations" }
                ),
                onTaskResultApplied = { response ->
                    events += "taskResultApplied:${response.type}"
                },
            )
        )
    }

    private companion object {
        fun batchItem(
            itemId: String,
            targetName: String,
            phoneNumber: String,
            status: String,
            headline: String,
            detail: String,
            transcript: String? = null
        ): BatchCallItemResultPayload {
            return BatchCallItemResultPayload(
                itemId = itemId,
                targetName = targetName,
                phoneNumber = phoneNumber,
                status = status,
                headline = headline,
                detail = detail,
                attemptCount = 1,
                recalled = false,
                abnormal = false,
                transcript = transcript
            )
        }
    }
}
