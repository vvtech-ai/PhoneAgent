package com.vvtech.aiassistant.features.assistant_home

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeVoiceRuntimeControllerGuardTest {
    @Test
    fun homeVoiceRuntimeLivesOutsideViewModel() {
        val viewModelFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomeViewModel.kt"
        )
        val controllerFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomeVoiceRuntimeController.kt"
        )
        val viewModel = viewModelFile.readText(Charsets.UTF_8)
        val controller = controllerFile.readText(Charsets.UTF_8)

        assertTrue(viewModelFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(controllerFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(viewModel.contains("private val voiceRuntimeController = AssistantHomeVoiceRuntimeController("))
        assertTrue(viewModel.contains("voiceRuntimeController.onAudioPermissionDenied()"))
        assertTrue(viewModel.contains("voiceRuntimeController.toggle(context, hasAudioPermission, requestAudioPermission)"))
        assertTrue(viewModel.contains("voiceRuntimeController.release()"))

        listOf(
            "VolcRtcVoiceClient",
            "VoiceRuntimeEvent",
            "VoiceRuntimeConfig",
            "StartRealtimeSessionRequest",
            "StopRealtimeSessionRequest",
            "private fun startVoiceSession",
            "private fun stopVoiceSession",
            "private fun handleVoiceEvent",
            "when (event)"
        ).forEach { token ->
            assertFalse("Home ViewModel should not own voice runtime token: $token", viewModel.contains(token))
            assertTrue("Home voice controller should own voice runtime token: $token", controller.contains(token))
        }
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
