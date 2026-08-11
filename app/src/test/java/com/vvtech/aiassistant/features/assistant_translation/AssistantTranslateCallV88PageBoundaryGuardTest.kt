package com.vvtech.aiassistant.features.assistant_translation

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslateCallV88PageBoundaryGuardTest {
    @Test
    fun translateCallPageBodyStaysInTranslationBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/V88TranslateCallPages.kt")
        val pageFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_translation/AssistantTranslateCallV88Page.kt"
        )
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val page = pageFile.readText(Charsets.UTF_8)

        assertTrue("V88TranslateCallPages should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 80)
        assertTrue("AssistantTranslateCallV88Page must stay below the new-file guard threshold.", pageFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy translate call entry should delegate to the translation boundary.",
            legacy.contains("import com.vvtech.aiassistant.features.assistant_translation.AssistantTranslateCallV88Page") &&
                legacy.contains("internal fun FinalTranslateCallPageV3Safe(") &&
                legacy.contains("AssistantTranslateCallV88Page(")
        )
        forbiddenLegacyTokens.forEach { token ->
            assertFalse("Translate call page body must not return to V88TranslateCallPages: $token", legacy.contains(token))
        }
        assertTrue(
            "V8.8 translate call page body should live in assistant_translation.",
            page.contains("internal fun AssistantTranslateCallV88Page(") &&
                page.contains("rememberLazyListState()") &&
                page.contains("TranslateSubtitlePanel(") &&
                page.contains("AssistantTranslateSection(") &&
                page.contains("AssistantTranslateCallControl(") &&
                page.contains("onHangup")
        )
        assertFalse("V62 translation call must not expose collapse copy.", page.contains("收起"))
        assertFalse("V62 translation call must not expose expand copy.", page.contains("展开"))
        assertFalse("V62 translation call must not show subtitle-updated copy.", page.contains("译文字幕已更新"))
        val mute = page.indexOf("label = \"静音\"")
        val hangup = page.indexOf("label = \"挂断\"")
        val speaker = page.indexOf("label = \"扬声器\"")
        assertTrue("Call controls must be ordered mute, hangup, speaker.", mute in 0 until hangup && hangup < speaker)
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Translate call page UI must not depend on runtime/business dependency: $dependency",
                page.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyTokens = listOf(
            "LazyColumn(",
            "rememberLazyListState(",
            "Brush.verticalGradient",
            "V88TranslateSection",
            "V88TranslateCallControl",
            "translationSubtitleRoleLabelSafe"
        )

        val bannedRuntimeDependencies = listOf(
            "Repository",
            "AssistantContainer",
            "AppContainer",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "AudioTrack",
            "MediaPlayer",
            "Asr",
            "Tts",
            "SIP",
            "AgentStream"
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
