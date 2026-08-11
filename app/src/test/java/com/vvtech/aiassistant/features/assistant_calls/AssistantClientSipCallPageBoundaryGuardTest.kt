package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantClientSipCallPageBoundaryGuardTest {
    @Test
    fun activeCallPageKeepsWorldCallStatusAndControlOrder() {
        val page = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantClientSipCallPage.kt"
        ).readText(Charsets.UTF_8)
        val thread = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantClientCallTranscriptThread.kt"
        ).readText(Charsets.UTF_8)
        val source = "$page\n$thread"

        assertTrue(source.contains("静音"))
        assertTrue(source.contains("拨号盘"))
        assertTrue(source.contains("扬声器"))
        assertTrue(source.contains("挂断"))
        assertTrue(source.indexOf("静音") < source.indexOf("拨号盘"))
        assertTrue(source.indexOf("拨号盘") < source.indexOf("扬声器"))
        assertTrue(source.indexOf("扬声器") < source.indexOf("挂断"))
        assertTrue(!source.contains("CallEnvironmentStatus"))
        assertTrue(source.contains("LazyColumn"))
        assertTrue(source.contains("state.transcripts"))
        assertTrue(source.contains("TranscriptMessageBubble"))
        assertTrue(source.contains("Alignment.CenterEnd"))
        assertTrue(source.contains("Alignment.CenterStart"))
        assertTrue(source.contains("translatedText"))
        assertTrue(source.contains("sourceText"))
        assertTrue(!source.contains("transcripts.lastOrNull()"))
    }

    private companion object {
        fun sourceFile(path: String): File = listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
