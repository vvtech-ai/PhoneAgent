package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionMeta
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionTerminalResultReducerTest {
    @Test
    fun preservesMatchingVisibleCallResult() {
        val state = Index9AssistantUiState(
            taskId = "task-1",
            callPageData = Index9AssistantUiState().callPageData.copy(
                status = "等待发起",
                transcript = listOf(TranscriptLine(TranscriptRole.Remote, "商家已接听"))
            )
        )

        val shouldPreserve = AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult(
            session = session(taskId = "task-1"),
            state = state,
            pendingAiCallLaunch = false
        )

        assertTrue(shouldPreserve)
    }

    @Test
    fun rejectsMismatchedOrEmptyVisibleCallResult() {
        assertFalse(
            AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult(
                session = session(taskId = "task-1"),
                state = Index9AssistantUiState(taskId = "task-2", currentCallId = "call-1"),
                pendingAiCallLaunch = true
            )
        )

        assertFalse(
            AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult(
                session = session(taskId = "task-1"),
                state = Index9AssistantUiState(taskId = "task-1"),
                pendingAiCallLaunch = false
            )
        )
    }

    @Test
    fun reducesTerminalResultWithoutDroppingVisibleCallPageData() {
        val callPageData = Index9AssistantUiState().callPageData.copy(
            status = "预订成功",
            transcript = listOf(TranscriptLine(TranscriptRole.Remote, "已预留包间"))
        )
        val state = Index9AssistantUiState(
            taskId = "old-task",
            sceneType = "GENERAL",
            taskStatus = "RUNNING",
            stage = AssistantStage.Clarifying,
            status = "通话中",
            liveUserTranscript = "用户说话",
            liveAssistantTranscript = "助手回复",
            loading = true,
            voiceConnecting = true,
            voiceActive = true,
            voiceManuallyPaused = true,
            listening = true,
            processingTurn = true,
            error = "old error",
            showAiCallPage = true,
            handoffInFlight = true,
            currentCallId = "call-1",
            callUiMode = CallUiMode.Human,
            callPageData = callPageData
        )

        val updated = AssistantSessionTerminalResultReducer.reduceTerminalResult(
            state = state,
            session = session(taskId = "task-1", sceneType = "RESTAURANT_BOOKING", taskStatus = "COMPLETED")
        )

        assertEquals("task-1", updated.taskId)
        assertEquals("RESTAURANT_BOOKING", updated.sceneType)
        assertEquals("COMPLETED", updated.taskStatus)
        assertEquals(AssistantStage.Recognized, updated.stage)
        assertEquals("预订成功", updated.status)
        assertEquals(callPageData, updated.callPageData)
        assertNull(updated.liveUserTranscript)
        assertNull(updated.liveAssistantTranscript)
        assertFalse(updated.loading)
        assertFalse(updated.voiceConnecting)
        assertFalse(updated.voiceActive)
        assertFalse(updated.voiceManuallyPaused)
        assertFalse(updated.listening)
        assertFalse(updated.processingTurn)
        assertNull(updated.error)
        assertFalse(updated.showAiCallPage)
        assertFalse(updated.handoffInFlight)
        assertNull(updated.currentCallId)
        assertEquals(CallUiMode.Ai, updated.callUiMode)
    }

    @Test
    fun terminalResultStatusKeepsExistingFallbackSemantics() {
        assertEquals("商家已确认", AssistantSessionTerminalResultReducer.terminalResultStatus("COMPLETED", "商家已确认"))
        assertEquals("通话未完成", AssistantSessionTerminalResultReducer.terminalResultStatus("FAILED", "等待发起"))
        assertEquals("通话未完成", AssistantSessionTerminalResultReducer.terminalResultStatus("CANCELED", ""))
        assertEquals("通话已结束", AssistantSessionTerminalResultReducer.terminalResultStatus("COMPLETED", "等待发起"))
    }

    @Test
    fun sessionMapperDelegatesTerminalResultStateMaintenance() {
        val mapper = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText()
        val initialHandlerFile =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionInitialApplyHandler.kt")
        val initialHandler = initialHandlerFile.readText()
        val initialStateHolder =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionInitialApplyStateHolder.kt")
                .readText()
        val reducer =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionTerminalResultReducer.kt")
                .readText()

        assertTrue(initialHandlerFile.readLines().size <= 300)
        assertTrue(mapper.contains("private val initialApplyHandler = AssistantSessionInitialApplyHandler("))
        assertTrue(mapper.contains("stateHolder = AssistantSessionInitialApplyStateHolder(deps.uiState)"))
        assertTrue(mapper.contains("initialApplyHandler.apply(session)"))
        assertFalse(mapper.contains("AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult"))
        assertFalse(mapper.contains("AssistantSessionTerminalResultReducer.reduceTerminalResult"))
        assertFalse(mapper.contains("isTerminalTaskStatus(session.session.taskStatus)"))
        assertFalse(mapper.contains("viewModel.pendingFreshTask = false"))
        assertFalse(mapper.contains("private fun terminalResultStatus"))
        assertFalse(mapper.contains("private fun looksLikeTerminalCallStatus"))
        assertFalse(mapper.contains("val hasVisibleCallResult"))

        assertTrue(initialHandler.contains("isTerminalTaskStatus(session.session.taskStatus)"))
        assertTrue(initialHandler.contains("deps.state.setPendingFreshTask(false)"))
        assertTrue(initialHandler.contains("val stateHolder: AssistantSessionInitialApplyStateHolder"))
        assertTrue(initialHandler.contains("deps.stateHolder.shouldPreserveTerminalResult("))
        assertTrue(initialHandler.contains("deps.stateHolder.preserveTerminalResult(session)"))
        assertFalse(initialHandler.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertFalse(initialHandler.contains("deps.uiState.value"))
        assertFalse(initialHandler.contains("deps.uiState.update"))
        assertFalse(initialHandler.contains("AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult"))
        assertFalse(initialHandler.contains("AssistantSessionTerminalResultReducer.reduceTerminalResult"))
        assertTrue(initialStateHolder.contains("internal class AssistantSessionInitialApplyStateHolder"))
        assertTrue(initialStateHolder.contains("private val uiState: MutableStateFlow<Index9AssistantUiState>"))
        assertTrue(initialStateHolder.contains("uiState.value"))
        assertTrue(initialStateHolder.contains("uiState.update"))
        assertTrue(initialStateHolder.contains("AssistantSessionTerminalResultReducer.shouldPreserveTerminalResult"))
        assertTrue(initialStateHolder.contains("AssistantSessionTerminalResultReducer.reduceTerminalResult(current, session)"))
        assertTrue(initialHandler.contains("deps.actions.resetToIdleHome()"))
        assertTrue(initialHandler.contains("deps.actions.refreshHistory()"))
        assertTrue(initialHandler.contains("deps.actions.applyNonTerminalSession(session)"))
        assertTrue(reducer.contains("fun shouldPreserveTerminalResult"))
        assertTrue(reducer.contains("fun reduceTerminalResult"))
        assertTrue(reducer.contains("fun terminalResultStatus"))
    }

    private fun session(
        taskId: String,
        sceneType: String = "AI_CALL",
        taskStatus: String = "COMPLETED"
    ): AssistantSessionResponse {
        return AssistantSessionResponse(
            session = AssistantSessionMeta(
                taskId = taskId,
                sceneType = sceneType,
                taskStatus = taskStatus,
                title = "AI 外呼",
                subtitle = null,
                waitingForUser = false
            ),
            messages = emptyList()
        )
    }
}
