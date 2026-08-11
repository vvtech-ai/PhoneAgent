package com.vvtech.aiassistant.features.assistant.speech

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskVoiceClientProviderBoundaryGuardTest {
    @Test
    fun viewModelCreatesTaskVoiceClientsThroughFactory() {
        val viewModel = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(viewModel.contains("TaskVoiceClientFactory.create(appContext)"))
        assertTrue(viewModel.contains("internal val taskAsrClient: TaskAsrClient"))
        assertFalse(viewModel.contains("import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskAsrSocketClient"))
        assertFalse(viewModel.contains("import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskTtsApiClient"))
        assertFalse(viewModel.contains("QwenTaskAsrSocketClient("))
        assertFalse(viewModel.contains("QwenTaskTtsApiClient("))
    }

    @Test
    fun providerFactoryOwnsConcreteQwenClientConstruction() {
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/TaskVoiceClientFactory.kt"
        ).readText(Charsets.UTF_8)
        val ttsFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/TaskTtsClientFactory.kt"
        ).readText(Charsets.UTF_8)
        val interfaceSource = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/TaskAsrClient.kt"
        ).readText(Charsets.UTF_8)
        val qwenClient = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/QwenTaskAsrSocketClient.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(interfaceSource.contains("internal interface TaskAsrClient"))
        assertTrue(factory.contains("asrClient = QwenTaskAsrSocketClient(context)"))
        assertTrue(factory.contains("ttsClient = TaskTtsClientFactory.create()"))
        assertFalse(factory.contains("import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskTtsApiClient"))
        assertFalse(factory.contains("QwenTaskTtsApiClient()"))
        assertTrue(ttsFactory.contains("fun create(): TtsApiClient"))
        assertTrue(ttsFactory.contains("return QwenTaskTtsApiClient()"))
        assertTrue(qwenClient.contains(": TaskAsrClient"))
        assertTrue(qwenClient.contains("override fun start("))
        assertTrue(qwenClient.contains("override fun stop()"))
        assertTrue(qwenClient.contains("override fun release()"))
        assertTrue(qwenClient.contains("override fun closeNow(reason: String)"))
    }

    @Test
    fun voiceRuntimeAndDuplexControllersUseProviderAgnosticAsrClientName() {
        orchestrationSources().forEach { source ->
            val text = source.readText(Charsets.UTF_8)
            assertFalse(
                "${source.path} should not use provider-specific ASR field name",
                text.contains("qwenTaskAsrSocketClient")
            )
            assertFalse(
                "${source.path} should not import Qwen ASR provider",
                text.contains("import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskAsrSocketClient")
            )
            assertFalse(
                "${source.path} should not import Qwen TTS provider",
                text.contains("import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskTtsApiClient")
            )
            assertFalse(
                "${source.path} should not construct Qwen TTS provider",
                text.contains("QwenTaskTtsApiClient(")
            )
        }

        assertTrue(sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeSessionController.kt"
        ).readText(Charsets.UTF_8).contains("taskAsrClient.start("))
        assertTrue(sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt"
        ).readText(Charsets.UTF_8).contains("taskAsrClient.stop()"))
    }

    private fun orchestrationSources(): List<File> {
        return listOf(
            "src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeSessionController.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeLifecycleController.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexRetryController.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexPlaybackController.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexCompletionController.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceAsrWatchdogController.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelRuntimeLifecycleHandler.kt"
        ).map(::sourceFile)
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
