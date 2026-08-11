package com.vvtech.aiassistant.features.assistant_lifecycle

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelRuntimeLifecycleHandlerGuardTest {
    @Test
    fun viewModelDelegatesRuntimeLifecycleWork() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()
        val facade = File("src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelTaskSessionFacades.kt")
            .readText()
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelRuntimeLifecycleHandler.kt")
                .readText()

        assertFalse(viewModel.contains("runtimeLifecycleHandler.initialize()"))
        assertTrue(facade.contains("runtimeLifecycleHandler.initialize()"))
        assertTrue(facade.contains("runtimeLifecycleHandler.onAccountIdentityChanged(hasSignedInAccount)"))
        assertTrue(facade.contains("runtimeLifecycleHandler.onRetry()"))
        assertTrue(viewModel.contains("runtimeLifecycleHandler.onCleared()"))
        assertTrue(viewModel.contains("super.onCleared()"))

        assertFalse(viewModel.contains("onAllPlaybackComplete ="))
        assertFalse(viewModel.contains("historyRecords = emptyList()"))
        assertFalse(viewModel.contains("showAiCallPage = false"))
        assertFalse(viewModel.contains("qwenTaskAsrSocketClient.release()"))
        assertFalse(viewModel.contains("QwenTaskAsrSocketClient("))
        assertFalse(viewModel.contains("QwenTaskTtsApiClient("))
        assertTrue(viewModel.contains("TaskVoiceClientFactory.create(appContext)"))

        assertTrue(handler.contains("onAllPlaybackComplete ="))
        assertFalse(handler.contains("clearLocalCallHistory"))
        assertTrue(handler.contains("showAiCallPage = false"))
        assertTrue(handler.contains("viewModel.taskAsrClient.release()"))
    }
}
