package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionPollingControllerTest {
    @Test
    fun shouldKeepPollingRequiresTaskAndActiveCallSurfaceOrPendingLaunch() {
        assertFalse(
            taskCallSessionShouldKeepPolling(
                state = Index9AssistantUiState(taskId = null, currentCallId = "call-1", showAiCallPage = true),
                pendingAiCallLaunch = true
            )
        )
        assertFalse(
            taskCallSessionShouldKeepPolling(
                state = Index9AssistantUiState(taskId = "task-1", currentCallId = null, showAiCallPage = false),
                pendingAiCallLaunch = false
            )
        )
        assertTrue(
            taskCallSessionShouldKeepPolling(
                state = Index9AssistantUiState(taskId = "task-1", currentCallId = "call-1", showAiCallPage = false),
                pendingAiCallLaunch = false
            )
        )
        assertTrue(
            taskCallSessionShouldKeepPolling(
                state = Index9AssistantUiState(taskId = "task-1", currentCallId = null, showAiCallPage = true),
                pendingAiCallLaunch = false
            )
        )
        assertTrue(
            taskCallSessionShouldKeepPolling(
                state = Index9AssistantUiState(taskId = "task-1", currentCallId = null, showAiCallPage = false),
                pendingAiCallLaunch = true
            )
        )
    }

    @Test
    fun callActionHandlerDelegatesPollingLifecycleToTaskController() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionPollingController.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("TaskCallSessionPollingController("))
        assertTrue(handler.contains("callSessionPollingController.start()"))
        assertTrue(handler.contains("callSessionPollingController.stop()"))
        assertTrue(handler.contains("callSessionPollingController.refresh()"))
        assertTrue(handler.contains("callSessionPollingController.shouldKeepPolling(state)"))
        assertFalse(handler.contains("viewModel.callSessionPollingJob = viewModel.viewModelScope.launch"))
        assertFalse(handler.contains("while (isActive && shouldKeepPollingCallSession"))
        assertFalse(handler.contains("delay(1500L)"))
        assertFalse(handler.contains("refreshCallSessionStatus_failed message="))
        assertFalse(handler.contains("callSessionCommandUseCase.refreshStatus("))

        assertTrue(controller.contains("while (isActive && shouldKeepPolling("))
        assertTrue(controller.contains("delay(CallSessionPollingIntervalMillis)"))
        assertTrue(controller.contains("refreshCallSessionStatus_failed message="))
        assertTrue(controller.contains("deps.commandUseCase.refreshStatus("))
        assertTrue(controller.contains("val userIdProvider: () -> String"))
        assertTrue(controller.contains("userId = deps.userIdProvider()"))
        assertFalse(controller.contains("val userId: String"))
        assertTrue(handler.contains("userIdProvider = { DefaultUserId }"))
        assertFalse(handler.contains("userId = DefaultUserId"))
        assertTrue(controller.contains("setPollingJob(null)"))
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
