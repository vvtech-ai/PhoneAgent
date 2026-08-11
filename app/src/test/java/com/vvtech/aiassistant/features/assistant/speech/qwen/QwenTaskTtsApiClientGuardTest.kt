package com.vvtech.aiassistant.features.assistant.speech.qwen

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QwenTaskTtsApiClientGuardTest {
    @Test
    fun qwenTtsClientKeepsSingleActiveTimeoutPath() {
        val clientFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/QwenTaskTtsApiClient.kt"
        )
        val client = clientFile.readText(Charsets.UTF_8)

        assertTrue(clientFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(client.contains("timeoutPendingWithSoftCompletion(current.generation, \"first_audio_timeout\")"))
        assertTrue(client.contains("timeoutPendingWithSoftCompletion(current.generation, \"completion_timeout\")"))
        assertTrue(client.contains("private sealed class TimeoutResult"))
        assertFalse(client.contains("private fun timeoutPending(generation: Long, reason: String)"))
        assertFalse(client.contains("语音播报异常：\$reason"))
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
