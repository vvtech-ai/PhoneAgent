package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PureVoiceState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.pureVoiceHasVisibleCallDialogue
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceThreadRenderStateTest {

    @Test
    fun manualHangupPendingOutcomeKeepsConversationAndCallTranscriptVisible() {
        val pendingText = "正在确认通话结果"
        val steps = listOf(
            ClarificationStep(
                role = VoiceRole.User,
                text = "帮我问一下餐厅还有没有包间",
                status = "已确认"
            ),
            ClarificationStep(
                role = VoiceRole.Assistant,
                text = "正在为你联系餐厅",
                status = "执行中"
            )
        )
        val transcript = listOf(
            TranscriptLine(TranscriptRole.Assistant, "您好，请问今晚还有包间吗？"),
            TranscriptLine(TranscriptRole.Remote, "有的，可以帮您预留。")
        )

        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.AiThinking,
            processingTurn = true,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = pendingText,
            clarificationSteps = steps,
            error = null,
            precheck = null,
            callPageData = CallPageData(
                name = "测试餐厅",
                sub = "AI 代打",
                status = pendingText,
                transcript = transcript
            ),
            showCallPage = false
        )

        assertEquals(steps, renderState.displayClarificationSteps)
        assertEquals(transcript, renderState.visibleCallTranscript?.transcript)
        assertEquals(pendingText, renderState.visiblePendingCallResultText)
        assertFalse(renderState.showEmptyState)
        assertFalse(renderState.showProcessingPlaceholder)
    }

    @Test
    fun callResultWithoutDialogueHidesTranscriptCard() {
        val data = callResultThreadPageData(
            result = CallResultPayload(
                status = "CANCELLED",
                headline = "通话未接通",
                detail = "用户在 App 端挂断通话",
                metadata = mapOf("agentOutcome" to "USER_CANCELLED")
            ),
            sceneType = "AI_CALL"
        )

        assertFalse(pureVoiceHasVisibleCallDialogue(data))
    }

    @Test
    fun callResultWithDialogueKeepsTranscriptForHistory() {
        val data = callResultThreadPageData(
            result = CallResultPayload(
                status = "FAILED",
                headline = "通话异常结束",
                detail = "对方中途挂断",
                metadata = mapOf(
                    "dialogueTranscript" to "AI：你好，请问现在方便吗？\n对方：你说。"
                )
            ),
            sceneType = "AI_CALL"
        )

        assertTrue(pureVoiceHasVisibleCallDialogue(data))
        assertEquals(2, data.transcript.count { it.role != TranscriptRole.Note })
    }

    @Test
    fun callResultWithOnlyAssistantTranscriptCountsAsRecordedDialogue() {
        val data = callResultThreadPageData(
            result = CallResultPayload(
                status = "FAILED",
                headline = "通话已结束",
                detail = "对方接听后立即挂断",
                metadata = mapOf(
                    "dialogueTranscript" to "assistant: 您好，我是 Chaken AI 助手。"
                )
            ),
            sceneType = "AI_CALL"
        )

        assertTrue(pureVoiceHasVisibleCallDialogue(data))
        assertEquals(
            listOf(TranscriptRole.Assistant),
            data.transcript.filter { it.role != TranscriptRole.Note }.map { it.role }
        )
    }

    @Test
    fun callResultWithOnlyRemoteTranscriptCountsAsRecordedDialogue() {
        val data = callResultThreadPageData(
            result = CallResultPayload(
                status = "FAILED",
                headline = "通话已结束",
                detail = "通话未完成",
                metadata = mapOf(
                    "dialogueTranscript" to "callee: 现在不方便。"
                )
            ),
            sceneType = "AI_CALL"
        )

        assertTrue(pureVoiceHasVisibleCallDialogue(data))
        assertEquals(
            listOf(TranscriptRole.Remote),
            data.transcript.filter { it.role != TranscriptRole.Note }.map { it.role }
        )
    }

    @Test
    fun assistantCompletedStepDoesNotReplaceTopWaveWithBrand() {
        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "",
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "想订什么呀？餐厅还是别的？",
                    status = "",
                    streaming = false
                )
            ),
            error = null,
            precheck = null,
            callPageData = null,
            showCallPage = false
        )

        assertEquals("语音待命中...", renderState.liveText)
        assertEquals(1, renderState.displayClarificationSteps.size)

        val content = File("src/main/java/com/vvtech/aiassistant/features/assistant/PureVoiceStageContent.kt").readText()
        val visuals = File("src/main/java/com/vvtech/aiassistant/features/assistant/PureVoiceStageVisuals.kt").readText()
        val state = File("src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceThreadRenderState.kt").readText()
        assertFalse(content.contains("completedAiOutput"))
        assertFalse(visuals.contains("PureVoiceCompletedAiBrand"))
        assertFalse(state.contains("showCompletedAiBrand"))
    }

    @Test
    fun restoredTimelineStatusWinsOverStaleWelcomePrompt() {
        val language = VoiceLanguage.Chinese
        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = language,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = language.firstWelcome,
            status = "任务失败，请重试",
            clarificationSteps = listOf(
                ClarificationStep(role = VoiceRole.User, text = "帮我打电话", status = "")
            ),
            error = null,
            precheck = null,
            callPageData = null,
            showCallPage = false,
        )

        assertEquals("任务失败，请重试", renderState.liveText)
    }

    @Test
    fun restoredCallResultKeepsVisiblePrecheckInline() {
        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "任务已完成",
            clarificationSteps = emptyList(),
            error = null,
            precheck = PureVoicePrecheckUiState(
                visible = true,
                inline = false,
                blocking = false,
                title = "任务执行环境检测",
                items = listOf(
                    PureVoicePrecheckItemUiState(
                        title = "网络连接",
                        value = "正常",
                        detail = "网络连接正常",
                        state = PureVoicePrecheckItemState.Passed
                    ),
                    PureVoicePrecheckItemUiState(
                        title = "大模型服务",
                        value = "千问 Omni-Flash-Realtime",
                        detail = "千问 Omni-Flash-Realtime 已就绪",
                        state = PureVoicePrecheckItemState.Passed
                    ),
                    PureVoicePrecheckItemUiState(
                        title = "外呼通道",
                        value = "检测中",
                        detail = "正在检查外呼通道",
                        state = PureVoicePrecheckItemState.Checking
                    )
                ),
                footer = ""
            ),
            callPageData = CallPageData(
                name = "AI助理",
                sub = "实时外呼",
                status = "任务已完成",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Assistant, "今晚8点。"),
                    TranscriptLine(TranscriptRole.Remote, "好的，帮你预定了。"),
                    TranscriptLine(TranscriptRole.Note, "AI代打结果：已完成")
                )
            ),
            showCallPage = false
        )

        assertNotNull(renderState.visibleCallTranscript)
        assertNotNull(renderState.visibleCallResult)
        assertTrue(renderState.showCallResult)
        assertNotNull(renderState.precheck)
        assertTrue(renderState.precheck!!.inline)
        assertEquals("任务执行环境检测中...", renderState.liveText)
    }

    @Test
    fun timelineCallResultRemainsInTimelineInsteadOfBeingReplacedByCallPageData() {
        val callResult = CallResultPayload(
            status = "COMPLETED",
            headline = "新荣记已订好",
            detail = "已成功预订明晚 18:00 新荣记新源南路店包房，8 位用餐。",
            metadata = mapOf(
                "dialogueTranscript" to "AI：你好，问一下明天晚上有包房吗？\n对方：请问几位用餐？"
            )
        )

        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "任务已完成",
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callResult = callResult
                )
            ),
            error = null,
            precheck = null,
            callPageData = CallPageData(
                name = "新荣记",
                sub = "实时外呼",
                status = "任务完成",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Assistant, "你好，问一下明天晚上有包房吗？"),
                    TranscriptLine(TranscriptRole.Remote, "请问几位用餐？"),
                    TranscriptLine(TranscriptRole.Note, "预订结果：新荣记已订好")
                )
            ),
            showCallPage = false
        )

        assertEquals(1, renderState.displayClarificationSteps.size)
        assertEquals(callResult, renderState.displayClarificationSteps.single().callResult)
        assertEquals(1, renderState.threadCount)
        assertNull(renderState.visibleCallTranscript)
        assertNull(renderState.visibleCallResult)
        assertFalse(renderState.showCallResult)
    }

    @Test
    fun timelineBatchReceiptHidesStandaloneCallPageReceiptAndTranscript() {
        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "未完成",
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "INCOMPLETE",
                    batchCallResult = BatchCallResultPayload(
                        status = "INCOMPLETE",
                        headline = "批量外呼完成",
                        items = listOf(
                            BatchCallItemResultPayload(
                                itemId = "item-1",
                                targetName = "餐厅",
                                phoneNumber = "",
                                status = "FAILED",
                                headline = "未完成",
                                detail = "无人接听",
                                attemptCount = 1,
                                recalled = false,
                                abnormal = true,
                                transcript = "AI：你好",
                            )
                        ),
                    ),
                )
            ),
            error = null,
            precheck = null,
            callPageData = CallPageData(
                name = "餐厅",
                sub = "实时外呼",
                status = "任务失败",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Assistant, "你好"),
                    TranscriptLine(TranscriptRole.Note, "未完成"),
                ),
            ),
            showCallPage = false,
        )

        assertEquals(1, renderState.displayClarificationSteps.size)
        assertNotNull(renderState.displayClarificationSteps.single().batchCallResult)
        assertNull(renderState.visibleCallTranscript)
        assertNull(renderState.visibleCallResult)
        assertFalse(renderState.showCallResult)
        assertEquals(1, renderState.threadCount)
    }

    @Test
    fun continuedTurnKeepsArchivedCallResultInTimelineInsteadOfTail() {
        val callResult = CallResultPayload(
            status = "COMPLETED",
            headline = "海底捞已订好",
            detail = "已成功预订晚上 10 点海底捞。",
            metadata = mapOf(
                "targetName" to "海底捞",
                "dialogueTranscript" to "AI：今晚10点还有包房吗？\n对方：可以预留。"
            )
        )

        val renderState = buildPureVoiceThreadRenderState(
            voiceLanguage = VoiceLanguage.Chinese,
            state = PureVoiceState.Standby,
            processingTurn = true,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = "正在处理，请稍候...",
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "",
                    status = "",
                    callResult = callResult
                ),
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "帮我改一下时间，改成7点吧。",
                    status = ""
                )
            ),
            error = null,
            precheck = null,
            callPageData = CallPageData(
                name = "海底捞",
                sub = "实时外呼",
                status = "任务完成",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Assistant, "今晚10点还有包房吗？"),
                    TranscriptLine(TranscriptRole.Remote, "可以预留。")
                )
            ),
            showCallPage = false
        )

        assertEquals(2, renderState.displayClarificationSteps.size)
        assertNotNull(renderState.displayClarificationSteps[0].callResult)
        assertEquals("帮我改一下时间，改成7点吧。", renderState.displayClarificationSteps[1].text)
        assertNull(renderState.visibleCallTranscript)
        assertNull(renderState.visibleCallResult)
        assertEquals(3, renderState.threadCount)
    }
}
