package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.finalCallTranscriptCards
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiCallHeaderPresentationTest {
    @Test
    fun showsConnectingUntilServerReportsConnected() {
        assertEquals("接通中 00:07", aiCallStatusWithDuration(callState = "", seconds = 7))
        assertEquals("接通中 01:05", aiCallStatusWithDuration(callState = "DIALING", seconds = 65))
        assertEquals("接通中 00:12", aiCallStatusWithDuration(callState = "ringing", seconds = 12))
    }

    @Test
    fun showsConnectedOnlyFromServerCallState() {
        assertEquals("已接通 02:03", aiCallStatusWithDuration(callState = "CONNECTED", seconds = 123))
        assertTrue(isAiCallConnected("CONNECTED"))
        assertTrue(isAiCallConnected(" connected "))
        assertFalse(isAiCallConnected("RINGING"))
    }

    @Test
    fun phoneLineNeverDisplaysTaskPurposeText() {
        assertEquals("02083196602", aiCallDisplayNumber("02083196602"))
        assertEquals("+86 20-8319 6602", aiCallDisplayNumber("+86 20-8319 6602"))
        assertEquals("", aiCallDisplayNumber("预订今晚8点的包间"))
        assertEquals("", aiCallDisplayNumber("实时外呼"))
    }

    @Test
    fun aiCallTimerRestartsWhenServerStateFirstBecomesConnected() {
        val effect = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRuntimeEffects.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(effect.contains("callConnected: Boolean"))
        assertTrue(
            effect.contains(
                "LaunchedEffect(currentPage == FinalPage.AiCall, showAiCallPage, callConnected)"
            )
        )
    }

    @Test
    fun aiCallPageUsesSingleServerStateLineWithoutLegacyChipOrTimer() {
        val page = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalAiCallPage.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(page.contains("aiCallStatusWithDuration(callData.callState, seconds)"))
        assertTrue(
            page.contains("aiCallDisplayNumber(phoneNumber.ifBlank { callData.sub })")
        )
        assertFalse(page.contains("val chipText ="))
        assertFalse(page.contains("AI代理通话"))
        assertFalse(page.contains("formatSeconds(seconds)"))
        assertFalse(page.contains("normalizeRealtimeCallProviderDisplayName(null, callModelTitle)"))
    }

    @Test
    fun transcriptPlaceholderAppearsOnlyAfterConnected() {
        assertTrue(finalCallTranscriptCards(emptyList(), includePlaceholder = false).isEmpty())
        assertEquals(
            listOf("实时对话记录" to "等待实时通话转写..."),
            finalCallTranscriptCards(emptyList(), includePlaceholder = true)
        )
    }

    @Test
    fun existingTranscriptContentRemainsVisibleBeforeConnected() {
        assertEquals(
            listOf("对方" to "现在不方便接听"),
            finalCallTranscriptCards(
                transcript = listOf(TranscriptLine(TranscriptRole.Remote, "现在不方便接听")),
                includePlaceholder = false
            )
        )
    }

    private fun sourceFile(path: String): File = listOf(File(path), File("android/app/$path"))
        .first { it.exists() }
}
