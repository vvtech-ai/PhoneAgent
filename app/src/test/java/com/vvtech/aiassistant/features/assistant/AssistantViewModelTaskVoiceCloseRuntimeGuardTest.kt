package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelTaskVoiceCloseRuntimeGuardTest {
    @Test
    fun viewModelDelegatesTaskVoiceRealtimeCloseToVoiceLifecycleController() {
        val viewModel = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        ).readText(Charsets.UTF_8)
        val facade = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelVoiceCallFacades.kt"
        ).readText(Charsets.UTF_8)
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/VoiceRuntimeHandler.kt"
        ).readText(Charsets.UTF_8)
        val lifecycle = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeLifecycleController.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(viewModel.lines().size < 500)
        assertTrue(handler.contains("internal fun closeTaskVoiceRealtime(reason: String) ="))
        assertTrue(handler.contains("lifecycleController.closeTaskVoiceRealtime(reason)"))
        assertFalse(viewModel.contains("internal fun closeTaskVoiceRealtime(reason: String) ="))
        assertTrue(facade.contains("internal fun AssistantViewModel.closeTaskVoiceRealtime(reason: String) ="))
        assertTrue(facade.contains("voiceRuntimeHandler.closeTaskVoiceRealtime(reason)"))

        listOf(
            "audioRecorder.stop()",
            "taskAsrClient.closeNow(reason)",
            "liveSpeechClient.stop()",
            "speechRecognizer.stop()",
            "ttsBridge.closeRealtime(reason)",
            "assistantSpeechPlayer.stop()",
            "AudioManager.MODE_NORMAL"
        ).forEach { token ->
            assertFalse("task voice close side effect should stay out of ViewModel: $token", viewModel.contains(token))
            assertFalse("task voice close side effect should stay out of facade: $token", facade.contains(token))
            assertTrue("voice lifecycle controller should own close side effect: $token", lifecycle.contains(token))
        }
        assertFalse("provider-specific ASR field name should stay out of lifecycle controller",
            lifecycle.contains("qwenTaskAsrSocketClient"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
