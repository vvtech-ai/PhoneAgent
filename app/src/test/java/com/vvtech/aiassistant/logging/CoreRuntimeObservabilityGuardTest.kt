package com.vvtech.aiassistant.logging

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CoreRuntimeObservabilityGuardTest {
    @Test
    fun aiCallOutcomeAndVoiceRecoveryUseStableStructuredEvents() {
        val voiceSession = source("features/assistant_voice/VoiceRuntimeSessionController.kt")
        val response = source("features/assistant_agent/AgentStreamResponseStateHandler.kt")
        val failure = source("features/assistant_agent/AgentStreamFailureRecoveryHandler.kt")
        val terminal = source("features/assistant_tasks/TaskCallSessionTerminalStatusController.kt")

        assertTrue(voiceSession.contains("VOICE_LISTEN_REQUESTED"))
        assertTrue(voiceSession.contains("VOICE_LISTEN_ALLOWED"))
        assertTrue(voiceSession.contains("VOICE_LISTEN_BLOCKED"))
        assertTrue(voiceSession.contains("trigger: String = VoiceListenTriggers.Unspecified"))

        assertTrue(response.contains("VoiceListenTriggers.AgentErrorRecovery"))
        assertTrue(response.contains("VoiceListenTriggers.AgentUnknownResponseRecovery"))
        assertTrue(response.contains("CALL_RESULT_APPLIED"))
        assertTrue(failure.contains("VoiceListenTriggers.AgentTransportFailureRecovery"))
        assertTrue(failure.contains("CALL_OUTCOME_WAITING"))

        assertTrue(terminal.contains("CALL_TRANSPORT_TERMINAL_DEFERRED"))
        assertTrue(terminal.contains("CALL_OUTCOME_WAITING"))
    }

    @Test
    fun otherCoreFeaturesUseUnifiedRuntimeLogger() {
        listOf(
            "features/assistant_lifecycle/AssistantViewModelRuntimeLifecycleHandler.kt",
            "features/assistant_session/AssistantConversationRestoreRuntimeHandler.kt",
            "features/assistant_contacts/AssistantContactDirectoryRuntimeController.kt",
            "features/assistant/AssistantOtaRuntimeController.kt",
            "features/app_logs/AssistantLogUploadRuntimeController.kt",
            "features/assistant_home/HomeCardEntryDispatcher.kt",
            "features/assistant/AssistantProviderRuntimeController.kt",
            "features/assistant/AssistantOutboundNumberRuntimeController.kt",
            "features/assistant_voice_clone/VoiceCloneRuntimeLogger.kt"
        ).forEach { path ->
            val content = source(path)
            assertTrue("$path should use RuntimeStateLogger", content.contains("RuntimeStateLogger"))
            assertTrue("$path should use RuntimeStateLogEvent", content.contains("RuntimeStateLogEvent"))
        }
        assertTrue(
            source("features/assistant/AssistantVoiceCloneRuntimeController.kt")
                .contains("logVoiceCloneRuntime")
        )
    }

    @Test
    fun ttsBridgeDoesNotLogRawTextPreviews() {
        val tts = source("features/assistant_agent/AgentStreamTtsBridgeHandler.kt")
        val playerBridge = source("features/assistant/viewmodel/AgentTtsBridge.kt")
        val takeoverSocket = source("features/assistant/TakeoverAudioSocketClient.kt")

        assertTrue(tts.contains("TTS_SIGNAL_RECEIVED"))
        assertTrue(tts.contains("\"textLength\" to text.length.toString()"))
        assertFalse(tts.contains("delta.take(30)"))
        assertFalse(tts.contains("text.take(50)"))
        assertFalse(tts.contains("previewText(text"))
        assertTrue(playerBridge.contains("deltaLength=\${delta.length}"))
        assertTrue(playerBridge.contains("textLength=\${sentence.length}"))
        assertFalse(playerBridge.contains("delta.take(30)"))
        assertFalse(playerBridge.contains("text.take(40)"))
        assertFalse(playerBridge.contains("sentence.take(40)"))
        assertFalse(takeoverSocket.contains("taskId=\$taskId url=\$url"))
    }

    private fun source(relativePath: String): String {
        val file = generateSequence(File(".").absoluteFile) { it.parentFile }
            .flatMap { root ->
                sequenceOf(
                    File(root, "src/main/java/com/vvtech/aiassistant/$relativePath"),
                    File(root, "android/app/src/main/java/com/vvtech/aiassistant/$relativePath")
                )
            }
            .firstOrNull { it.exists() }
            ?: error("source not found: $relativePath")
        return file.readText(Charsets.UTF_8)
    }
}
