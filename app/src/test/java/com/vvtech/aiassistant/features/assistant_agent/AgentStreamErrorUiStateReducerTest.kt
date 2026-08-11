package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamErrorUiStateReducerTest {
    @Test
    fun appliesStreamErrorForTextModeErrEvent() {
        val state = Index9AssistantUiState(
            processingTurn = true,
            loading = true,
            error = null,
            status = "AI处理中"
        )

        val updated = AgentStreamErrorUiStateReducer.applyStreamError(state, "网络异常")

        assertFalse(updated.processingTurn)
        assertFalse(updated.loading)
        assertEquals("网络异常", updated.error)
        assertEquals("网络异常", updated.status)
    }

    @Test
    fun appliesExecutionErrorFields() {
        val state = Index9AssistantUiState(
            processingTurn = true,
            loading = true,
            taskStatus = "ACTIVE",
            unresolvedTaskErrorStatus = "OLD",
            taskErrorRecoveryInProgress = true,
            agentDocumentImporting = true
        )

        val updated = AgentStreamErrorUiStateReducer.applyExecutionError(
            state = state,
            errorText = "执行失败",
            statusText = "出错了",
            clearDocumentImporting = true
        )

        assertFalse(updated.processingTurn)
        assertFalse(updated.loading)
        assertEquals("EXECUTION_ERROR", updated.taskStatus)
        assertEquals("EXECUTION_ERROR", updated.unresolvedTaskErrorStatus)
        assertFalse(updated.taskErrorRecoveryInProgress)
        assertEquals("执行失败", updated.error)
        assertEquals("出错了", updated.status)
        assertFalse(updated.agentDocumentImporting)
    }

    @Test
    fun appliesVoiceRecoveryWithOptionalCleanup() {
        val state = Index9AssistantUiState(
            processingTurn = true,
            loading = true,
            error = "旧错误",
            status = "旧状态",
            voiceManuallyPaused = true,
            agentDocumentImporting = true
        )

        val updated = AgentStreamErrorUiStateReducer.applyVoiceRecovery(
            state = state,
            statusText = "已恢复，请继续说",
            resetManualPause = true,
            clearDocumentImporting = true
        )

        assertFalse(updated.processingTurn)
        assertFalse(updated.loading)
        assertNull(updated.error)
        assertEquals("已恢复，请继续说", updated.status)
        assertFalse(updated.voiceManuallyPaused)
        assertFalse(updated.agentDocumentImporting)
    }

    @Test
    fun appliesBatchSyncPendingWithClearErrorFlag() {
        val state = Index9AssistantUiState(
            processingTurn = true,
            loading = true,
            listening = true,
            voiceConnecting = true,
            apiAsrListening = true,
            apiAsrPartialText = "用户说话",
            error = "旧错误"
        )

        val keepError = AgentStreamErrorUiStateReducer.applyBatchSyncPending(
            state = state,
            statusText = "多路外呼结果同步中，请稍后刷新",
            clearError = false
        )
        assertFalse(keepError.processingTurn)
        assertFalse(keepError.loading)
        assertFalse(keepError.listening)
        assertFalse(keepError.voiceConnecting)
        assertFalse(keepError.apiAsrListening)
        assertNull(keepError.apiAsrPartialText)
        assertEquals("旧错误", keepError.error)
        assertEquals("多路外呼结果同步中，请稍后刷新", keepError.status)

        val clearError = AgentStreamErrorUiStateReducer.applyBatchSyncPending(
            state = state,
            statusText = "多路外呼结果同步中，请稍后刷新",
            clearError = true
        )
        assertNull(clearError.error)
    }

    @Test
    fun agentStreamHandlerDelegatesErrorUiStateReducer() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val eventHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamEventHandler.kt")
                .readText(Charsets.UTF_8)
        val failureRecoveryHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamFailureRecoveryHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(eventHandler.contains("AgentStreamErrorUiStateReducer.applyStreamError"))
        assertTrue(eventHandler.contains("AgentStreamErrorUiStateReducer.applyBatchSyncPending"))
        assertTrue(failureRecoveryHandler.contains("AgentStreamErrorUiStateReducer.applyExecutionError"))
        assertTrue(failureRecoveryHandler.contains("AgentStreamErrorUiStateReducer.applyVoiceRecovery"))
        assertTrue(failureRecoveryHandler.contains("AgentStreamErrorUiStateReducer.applyBatchSyncPending"))
        assertTrue(handler.contains("AgentStreamFailureRecoveryHandler("))
        assertFalse(handler.contains("AgentStreamErrorUiStateReducer.applyStreamError"))
        assertFalse(handler.contains("AgentStreamErrorUiStateReducer.applyExecutionError"))
        assertFalse(handler.contains("AgentStreamErrorUiStateReducer.applyVoiceRecovery"))
        assertFalse(handler.contains("AgentStreamErrorUiStateReducer.applyBatchSyncPending"))

        assertFalse(handler.contains("unresolvedTaskErrorStatus = \"EXECUTION_ERROR\""))
        assertFalse(handler.contains("taskErrorRecoveryInProgress = false"))
        assertFalse(handler.contains("status = \"多路外呼结果同步中，请稍后刷新\""))
    }
}
