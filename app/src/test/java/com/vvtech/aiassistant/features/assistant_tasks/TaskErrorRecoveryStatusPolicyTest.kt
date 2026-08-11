package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.shouldPersistExecutionErrorOnTaskExit
import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskErrorRecoveryStatusPolicyTest {
    @Test
    fun pendingExecutionErrorExitOverridesOnlyMatchingSessions() {
        val conversations = listOf(
            ConversationListItem(sessionId = "session-1", title = "task one", status = "RUNNING"),
            ConversationListItem(sessionId = "session-2", title = "task two", status = "COMPLETED")
        )

        val updated = conversations.withPendingExecutionErrorExitStatuses(setOf(" session-1 "))

        assertEquals("EXECUTION_ERROR", updated[0].status)
        assertEquals("COMPLETED", updated[1].status)
    }

    @Test
    fun recoveredExecutionErrorDoesNotGuessStableStatusBeforeCanonicalSync() {
        val conversations = listOf(
            ConversationListItem(sessionId = "session-1", title = "task one", status = "EXECUTION_ERROR"),
            ConversationListItem(sessionId = "session-2", title = "task two", status = "COMPLETED")
        )

        val updated = conversations.withRecoveredExecutionErrorStatuses(setOf("session-1"))

        assertEquals("EXECUTION_ERROR", updated[0].status)
        assertEquals("COMPLETED", updated[1].status)
    }

    @Test
    fun confirmedRecoveryPreservesStatusUntilCanonicalSync() {
        assertEquals("EXECUTION_ERROR", taskStatusAfterConfirmedErrorRecovery("EXECUTION_ERROR"))
        assertEquals("NETWORK_ERROR", taskStatusAfterConfirmedErrorRecovery("NETWORK_ERROR"))
        assertEquals("tool_error", taskStatusAfterConfirmedErrorRecovery("tool_error"))
        assertEquals("COMPLETED", taskStatusAfterConfirmedErrorRecovery("COMPLETED"))
        assertEquals("custom_state", taskStatusAfterConfirmedErrorRecovery("custom_state"))
    }

    @Test
    fun recoveryUiReducerMarksRecoveryInProgress() {
        val state = Index9AssistantUiState(
            taskStatus = "RUNNING",
            unresolvedTaskErrorStatus = null,
            taskErrorRecoveryInProgress = false
        )

        val next = TaskErrorRecoveryUiStateReducer.markRecoveryInProgress(
            state = state,
            status = "EXECUTION_ERROR"
        )

        assertEquals("RUNNING", next.taskStatus)
        assertEquals("EXECUTION_ERROR", next.unresolvedTaskErrorStatus)
        assertTrue(next.taskErrorRecoveryInProgress)
    }

    @Test
    fun recoveryUiReducerKeepsCallContextOnNetworkError() {
        val state = Index9AssistantUiState(
            showAiCallPage = true,
            currentCallId = "call-1",
            voiceConnecting = true,
            loading = true,
            listening = true,
            apiAsrListening = true,
            apiAsrPartialText = "partial",
            liveUserTranscript = "user",
            callPageData = Index9AssistantUiState().callPageData.copy(status = "通话中")
        )

        val next = TaskErrorRecoveryUiStateReducer.applyNetworkTaskErrorState(
            state = state,
            keepCallContext = true,
            message = TaskCallNetworkReconnectingStatus
        )

        assertEquals(TaskCallNetworkReconnectingStatus, next.error)
        assertEquals(TaskCallNetworkReconnectingStatus, next.status)
        assertEquals(TaskCallNetworkReconnectingStatus, next.callPageData.status)
        assertEquals("INIT", next.taskStatus)
        assertFalse(next.loading)
        assertFalse(next.voiceConnecting)
        assertFalse(next.listening)
        assertFalse(next.apiAsrListening)
        assertNull(next.apiAsrPartialText)
        assertNull(next.liveUserTranscript)
    }

    @Test
    fun recoveryUiReducerMarksRegularNetworkErrorAsRecoverablePause() {
        val state = Index9AssistantUiState(
            taskStatus = "RUNNING",
            voiceActive = false,
            voiceBackgroundPaused = true,
            listening = true,
            processingTurn = true,
            loading = true,
            apiAsrListening = true,
            apiAsrPartialText = "partial",
            liveUserTranscript = "user"
        )

        val next = TaskErrorRecoveryUiStateReducer.applyNetworkTaskErrorState(
            state = state,
            keepCallContext = false,
            message = "网络异常"
        )

        assertEquals("NETWORK_ERROR", next.taskStatus)
        assertEquals("NETWORK_ERROR", next.unresolvedTaskErrorStatus)
        assertFalse(next.taskErrorRecoveryInProgress)
        assertTrue(next.voiceManuallyPaused)
        assertFalse(next.voiceBackgroundPaused)
        assertTrue(next.voiceActive)
        assertFalse(next.listening)
        assertFalse(next.processingTurn)
        assertFalse(next.loading)
        assertFalse(next.apiAsrListening)
        assertNull(next.apiAsrPartialText)
        assertNull(next.liveUserTranscript)
        assertEquals("网络异常", next.error)
        assertEquals("网络异常", next.status)
    }

    @Test
    fun recoveryUiReducerPromotesConfirmedRecoverableErrorBeforeExit() {
        val state = Index9AssistantUiState(
            taskStatus = "EXECUTION_ERROR",
            unresolvedTaskErrorStatus = "EXECUTION_ERROR",
            taskErrorRecoveryInProgress = true
        )

        val plan = TaskErrorRecoveryUiStateReducer.confirmedRecoveryPlan(
            state = state,
            promoteToRunning = true
        )
        val next = TaskErrorRecoveryUiStateReducer.applyConfirmedRecovery(state, plan)

        assertTrue(plan.shouldApply)
        assertTrue(plan.recoverableStatus)
        assertEquals("RUNNING", plan.recoveredStatus)
        assertEquals("RUNNING", next.taskStatus)
        assertNull(next.unresolvedTaskErrorStatus)
        assertFalse(next.taskErrorRecoveryInProgress)
        assertFalse(
            shouldPersistExecutionErrorOnTaskExit(
                taskStatus = next.taskStatus,
                unresolvedTaskErrorStatus = next.unresolvedTaskErrorStatus,
                taskErrorRecoveryInProgress = next.taskErrorRecoveryInProgress
            )
        )
    }

    @Test
    fun recoveryUiReducerSkipsConfirmedRecoveryForNonRecoverableIdleState() {
        val state = Index9AssistantUiState(
            taskStatus = "COMPLETED",
            unresolvedTaskErrorStatus = null,
            taskErrorRecoveryInProgress = false
        )

        val plan = TaskErrorRecoveryUiStateReducer.confirmedRecoveryPlan(
            state = state,
            promoteToRunning = true
        )

        assertFalse(plan.shouldApply)
        assertFalse(plan.recoverableStatus)
        assertEquals("COMPLETED", plan.recoveredStatus)
    }

    @Test
    fun taskErrorRecoveryHolderBelongsToTaskBoundary() {
        val oldHolder = sourceFileOrNull(
            "src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/TaskErrorRecoveryHolder.kt"
        )
        val holder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryHolder.kt"
        ).readText(Charsets.UTF_8)
        val uiStateHolder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryUiStateHolder.kt"
        ).readText(Charsets.UTF_8)
        val confirmController = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryConfirmController.kt"
        ).readText(Charsets.UTF_8)
        val networkStateHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryNetworkStateHandler.kt"
        ).readText(Charsets.UTF_8)
        val viewModel = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        ).readText(Charsets.UTF_8)
        val viewModelReducer = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/AssistantUiStateReducer.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(oldHolder?.exists() == true)
        assertTrue(holder.contains("package com.vvtech.aiassistant.features.assistant_tasks"))
        assertTrue(holder.contains("private val uiStateHolder = TaskErrorRecoveryUiStateHolder(uiState)"))
        assertTrue(holder.contains("private val networkStateHandler = TaskErrorRecoveryNetworkStateHandler("))
        assertTrue(holder.contains("private val confirmController = TaskErrorRecoveryConfirmController("))
        assertTrue(holder.contains("uiStateHolder = uiStateHolder"))
        assertTrue(holder.contains("networkStateHandler.applyNetworkTaskErrorState(raw)"))
        assertTrue(holder.contains("confirmController.confirm(reason, promoteToRunning)"))
        assertTrue(holder.contains("uiStateHolder.markRecoveryInProgress(status)"))
        assertFalse(holder.contains("uiState.update"))
        assertFalse(holder.contains("TaskErrorRecoveryUiStateReducer.markRecoveryInProgress"))
        assertFalse(holder.contains("TaskErrorRecoveryUiStateReducer.confirmedRecoveryPlan"))
        assertFalse(holder.contains("TaskErrorRecoveryUiStateReducer.applyConfirmedRecovery"))
        assertFalse(holder.contains("TaskErrorRecoveryUiStateReducer.applyNetworkTaskErrorState"))
        assertFalse(holder.contains("closeTaskVoiceRealtime(\"network_task_error\")"))
        assertFalse(holder.contains("private fun isAiCallContextActive"))
        assertFalse(holder.contains("private fun previewText"))
        assertTrue(uiStateHolder.contains("internal class TaskErrorRecoveryUiStateHolder"))
        assertTrue(uiStateHolder.contains("private val uiState: MutableStateFlow<Index9AssistantUiState>"))
        assertTrue(uiStateHolder.contains("fun currentState(): Index9AssistantUiState = uiState.value"))
        assertTrue(uiStateHolder.contains("TaskErrorRecoveryUiStateReducer.markRecoveryInProgress"))
        assertTrue(uiStateHolder.contains("TaskErrorRecoveryUiStateReducer.applyNetworkTaskErrorState"))
        assertTrue(uiStateHolder.contains("TaskErrorRecoveryUiStateReducer.confirmedRecoveryPlan"))
        assertTrue(uiStateHolder.contains("TaskErrorRecoveryUiStateReducer.applyConfirmedRecovery"))
        assertTrue(uiStateHolder.contains("uiState.update"))
        assertTrue(networkStateHandler.contains("private val uiStateHolder: TaskErrorRecoveryUiStateHolder"))
        assertTrue(networkStateHandler.contains("uiStateHolder.applyNetworkTaskErrorState("))
        assertTrue(networkStateHandler.contains("val state = uiStateHolder.currentState()"))
        assertTrue(networkStateHandler.contains("closeTaskVoiceRealtime(\"network_task_error\")"))
        assertTrue(networkStateHandler.contains("applyNetworkTaskErrorState keep_call_context"))
        assertTrue(networkStateHandler.contains("private fun isAiCallContextActive"))
        assertTrue(networkStateHandler.contains("private fun previewText"))
        assertFalse(networkStateHandler.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertFalse(networkStateHandler.contains("uiState.update"))
        assertFalse(networkStateHandler.contains("TaskErrorRecoveryUiStateReducer.applyNetworkTaskErrorState"))
        assertTrue(confirmController.contains("private val uiStateHolder: TaskErrorRecoveryUiStateHolder"))
        assertTrue(confirmController.contains("val state = uiStateHolder.currentState()"))
        assertTrue(confirmController.contains("val confirmedPlan = uiStateHolder.confirmedRecoveryPlan(promoteToRunning)"))
        assertTrue(confirmController.contains("uiStateHolder.applyConfirmedRecovery(confirmedPlan)"))
        assertTrue(confirmController.contains("rememberPendingExecutionErrorRecovered(sessionId)"))
        assertTrue(confirmController.contains("syncPendingExecutionErrorRecoveredSessions()"))
        assertTrue(confirmController.contains("scope.launch"))
        assertTrue(confirmController.contains("markTaskErrorRecoveryConfirmed reason=\$reason"))
        assertFalse(confirmController.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertFalse(confirmController.contains("uiState.update"))
        assertFalse(confirmController.contains("TaskErrorRecoveryUiStateReducer.confirmedRecoveryPlan"))
        assertFalse(confirmController.contains("TaskErrorRecoveryUiStateReducer.applyConfirmedRecovery"))
        assertFalse(holder.contains("taskStatusAfterConfirmedErrorRecovery"))
        assertFalse(holder.contains("callPageData = it.callPageData.copy"))
        assertFalse(holder.contains("voiceManuallyPaused = true"))
        assertFalse(holder.contains("AssistantUiStateReducer"))
        assertFalse(holder.contains("features.assistant.viewmodel"))
        assertTrue(viewModel.contains("features.assistant_tasks.TaskErrorRecoveryHolder"))
        assertFalse(viewModel.contains("features.assistant.viewmodel.TaskErrorRecoveryHolder"))
        assertFalse(viewModelReducer.contains("markTaskErrorRecoveryInProgress"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return sourceFileOrNull(path) ?: error("Missing source file: $path")
        }

        fun sourceFileOrNull(path: String): File? {
            return listOf(
                File(path),
                File("android/app/$path")
            ).firstOrNull { it.exists() }
        }
    }
}
