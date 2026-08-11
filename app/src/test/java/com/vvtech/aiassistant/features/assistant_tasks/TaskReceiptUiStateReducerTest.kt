package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskReceiptUiStateReducerTest {
    @Test
    fun terminalDisplayReducerClosesCallPageAndKeepsTerminalStatus() {
        val state = Index9AssistantUiState(
            stage = AssistantStage.Clarifying,
            status = "通话中",
            loading = true,
            voiceConnecting = true,
            voiceActive = true,
            voiceManuallyPaused = true,
            listening = true,
            processingTurn = true,
            error = "old-error",
            taskStatus = "RUNNING",
            callUiMode = CallUiMode.Human,
            currentCallId = "call-1",
            handoffInFlight = true,
            showAiCallPage = true
        )
        val plan = CallSessionTerminalDisplayPlan(
            historyStatus = "未完成",
            historyStyle = StatusStyle.Failure,
            taskStatus = "INCOMPLETE",
            statusText = "商家未接通"
        )

        val next = TaskReceiptUiStateReducer.applyCallSessionTerminalDisplay(state, plan)

        assertEquals(AssistantStage.Recognized, next.stage)
        assertEquals("INCOMPLETE", next.taskStatus)
        assertEquals("商家未接通", next.status)
        assertEquals("商家未接通", next.callPageData.status)
        assertFalse(next.loading)
        assertFalse(next.voiceConnecting)
        assertFalse(next.voiceActive)
        assertFalse(next.voiceManuallyPaused)
        assertFalse(next.listening)
        assertFalse(next.processingTurn)
        assertFalse(next.showAiCallPage)
        assertFalse(next.handoffInFlight)
        assertNull(next.error)
        assertNull(next.currentCallId)
        assertEquals(CallUiMode.Ai, next.callUiMode)
    }

    @Test
    fun callResultStatusClearsTurnLoading() {
        val state = Index9AssistantUiState(
            processingTurn = true,
            loading = true,
            callPageData = Index9AssistantUiState().callPageData.copy(status = "通话中")
        )

        val next = TaskReceiptUiStateReducer.applyCallResultStatus(state, "任务完成")

        assertEquals("任务完成", next.callPageData.status)
        assertFalse(next.processingTurn)
        assertFalse(next.loading)
    }

    @Test
    fun nonTerminalDisplayProjectsRawCallStateToCallPageData() {
        val response = CallSessionStatusResponse(
            callId = "call-1",
            taskId = "task-1",
            sceneType = "FOOD_ORDERING",
            targetName = "测试餐厅",
            phoneNumber = "07550000000",
            callState = "RINGING",
            handoffMode = "AI_ACTIVE",
            backendCallEnabled = true,
            handoffSupported = true,
            appRtcRequired = false,
            statusMessage = "正在呼叫",
            resultCode = "",
            updatedAt = "2026-08-05T10:00:00"
        )
        val facts = TaskCallSessionStatusFacts(
            humanMode = false,
            humanRequested = false,
            terminalCallState = false,
            protectTakeoverState = false,
            note = null,
            shouldStartTakeoverAudio = false,
            shouldStopTakeoverAudio = false
        )

        val next = TaskReceiptUiStateReducer.applyCallSessionNonTerminalDisplay(
            state = Index9AssistantUiState(),
            response = response,
            facts = facts,
            rebuiltTranscript = emptyList()
        )

        assertEquals("RINGING", next.callPageData.callState)
    }

    @Test
    fun pendingAgentOutcomeDisplayPreservesTaskConversationAndCallTranscript() {
        val steps = listOf(
            ClarificationStep(VoiceRole.User, "帮我联系餐厅", "已确认"),
            ClarificationStep(VoiceRole.Assistant, "正在拨打电话", "执行中")
        )
        val transcript = listOf(
            TranscriptLine(TranscriptRole.Assistant, "您好，请问今晚还有位置吗？"),
            TranscriptLine(TranscriptRole.Remote, "有位置，可以预留。")
        )
        val state = Index9AssistantUiState(
            taskStatus = "COMPLETED",
            status = "已完成",
            processingTurn = false,
            clarificationSteps = steps,
            callPageData = CallPageData(
                name = "测试餐厅",
                sub = "AI 代打",
                status = "通话中",
                transcript = transcript
            )
        )

        val next = TaskReceiptUiStateReducer.applyCallOutcomePendingDisplay(
            state = state,
            pendingText = "正在确认通话结果"
        )

        assertEquals("COMPLETED", next.taskStatus)
        assertEquals("正在确认通话结果", next.status)
        assertEquals(steps, next.clarificationSteps)
        assertEquals(transcript, next.callPageData.transcript)
        assertTrue(next.processingTurn)
    }

    @Test
    fun physicalTerminalThenSemanticFailureMovesFromRunningToIncompleteWithoutLegacyStatus() {
        val pending = TaskReceiptUiStateReducer.applyCallOutcomePendingDisplay(
            state = Index9AssistantUiState(taskStatus = "RUNNING"),
            pendingText = "正在确认通话结果"
        )
        val plan = callSessionTerminalDisplayPlan(
            response = CallSessionStatusResponse(
                callId = "call-1",
                taskId = "task-1",
                sceneType = "FOOD_ORDERING",
                targetName = "餐厅",
                phoneNumber = "07550000000",
                callState = "FAILED",
                handoffMode = "FAILED",
                backendCallEnabled = true,
                handoffSupported = true,
                appRtcRequired = false,
                statusMessage = "预订未确认",
                resultCode = "INCOMPLETE_OR_UNCLEAR",
                updatedAt = "2026-07-22T16:00:00"
            ),
            existingHistoryStatus = null,
            currentCallUiMode = CallUiMode.Ai
        )
        val terminal = TaskReceiptUiStateReducer.applyCallSessionTerminalDisplay(pending, plan)

        assertEquals("RUNNING", pending.taskStatus)
        assertEquals("INCOMPLETE", terminal.taskStatus)
        assertEquals("未完成", terminal.status)
    }

    @Test
    fun callActionHandlerDelegatesTerminalStateToTaskReducer() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionStatusApplyController.kt")
                .readText(Charsets.UTF_8)
        val terminalController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionTerminalStatusController.kt")
                .readText(Charsets.UTF_8)
        val reducer =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskReceiptUiStateReducer.kt")
                .readText(Charsets.UTF_8)
        val displayPolicy =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallResultDisplayPolicy.kt")
                .readText(Charsets.UTF_8)

        assertEquals(0, handler.countLiteral("callSessionTerminalDisplayPlan("))
        assertEquals(0, handler.countLiteral("applyCallSessionTerminalDisplay"))
        assertEquals(0, controller.countLiteral("callSessionTerminalDisplayPlan("))
        assertEquals(0, controller.countLiteral("applyCallSessionTerminalDisplay"))
        assertEquals(1, terminalController.countLiteral("callSessionTerminalDisplayPlan("))
        assertEquals(1, terminalController.countLiteral("applyCallSessionTerminalDisplay"))
        assertFalse(handler.contains("val terminalTaskStatus ="))
        assertFalse(handler.contains("val terminalStatusText ="))
        assertFalse(handler.contains("stage = AssistantStage.Recognized"))
        assertFalse(handler.contains("showAiCallPage = false,\n                    handoffInFlight = false"))

        assertEquals(1, reducer.countLiteral("fun applyCallSessionTerminalDisplay"))
        assertEquals(1, displayPolicy.countLiteral("fun callSessionTerminalDisplayPlan"))
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }

        fun String.countLiteral(value: String): Int {
            if (value.isEmpty()) return 0
            return split(value).size - 1
        }
    }
}
