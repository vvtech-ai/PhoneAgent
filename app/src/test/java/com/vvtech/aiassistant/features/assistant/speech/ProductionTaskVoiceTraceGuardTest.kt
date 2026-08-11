package com.vvtech.aiassistant.features.assistant.speech

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductionTaskVoiceTraceGuardTest {

    @Test
    fun androidProductionSourcesDoNotKeepTaskVoiceTraceOrAudioDumpHooks() {
        val sourceRoot = File("src/main/java")
        val forbidden = listOf(
            "TaskVoiceTrace",
            "TASK_VOICE_TRACE",
            "VOICE_TIMELINE",
            "VOICE_MODEL_DIAG",
            "appendTaskVoice",
            "taskVoiceTraceId",
            "currentTaskVoiceTraceId"
        )
        val hits = sourceRoot.walkTopDown()
            .filter { it.isFile && (it.extension == "kt" || it.extension == "java") }
            .flatMap { file ->
                val text = file.readText()
                forbidden
                    .filter { token -> text.contains(token) }
                    .map { token -> "${file.relativeTo(sourceRoot).path}:$token" }
            }
            .toList()

        assertTrue(
            "Production Android sources should not keep task voice trace logging or audio dump hooks: $hits",
            hits.isEmpty()
        )
    }
}
