package com.vvtech.aiassistant.features.assistant_ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoiceIndicatorsGuardTest {
    @Test
    fun voiceIndicatorImplementationStaysOutOfLegacySharedComponents() {
        val sharedFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalSharedComponents.kt")
        val indicatorFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantVoiceIndicators.kt")
        val shared = sharedFile.readText(Charsets.UTF_8)
        val indicators = indicatorFile.readText(Charsets.UTF_8)

        assertTrue("FinalSharedComponents should stay at or below 300 lines after indicator extraction.", sharedFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue("AssistantVoiceIndicators must stay below the new-file guard threshold.", indicatorFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy shared components should only keep thin compatibility wrappers for voice indicators.",
            shared.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantVoiceWave") &&
                shared.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantPauseGlyph") &&
                shared.contains("fun FinalVoiceWave() = AssistantVoiceWave()") &&
                shared.contains("fun FinalPauseGlyph() = AssistantPauseGlyph()")
        )
        assertTrue(
            "Voice indicator implementation should live in the assistant_ui component boundary.",
            indicators.contains("internal fun AssistantVoiceWave()") &&
                indicators.contains("internal fun AssistantPauseGlyph()") &&
                indicators.contains("rememberInfiniteTransition")
        )
        assertFalse(
            "Wave animation internals must not return to FinalSharedComponents.",
            shared.contains("rememberInfiniteTransition") ||
                shared.contains("waveScaleA") ||
                shared.contains("val scaleA") ||
                shared.contains("val heights = listOf")
        )
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Pure UI voice indicators must not depend on runtime/business dependency: $dependency",
                indicators.contains(dependency)
            )
        }
    }

    private companion object {
        val bannedRuntimeDependencies = listOf(
            "Repository",
            "AssistantContainer",
            "AppContainer",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "Tts",
            "Asr",
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
