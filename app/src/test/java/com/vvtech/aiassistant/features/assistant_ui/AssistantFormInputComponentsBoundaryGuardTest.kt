package com.vvtech.aiassistant.features.assistant_ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantFormInputComponentsBoundaryGuardTest {
    @Test
    fun sharedFormInputImplementationStaysInUiBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalSharedFormComponents.kt")
        val componentFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantFormInputComponents.kt"
        )
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val component = componentFile.readText(Charsets.UTF_8)

        assertTrue("Legacy shared form file should stay below the transition-file guard threshold.", legacyFile.readLines(Charsets.UTF_8).size <= 160)
        assertTrue("Assistant form input component file must stay below the new-file guard threshold.", componentFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(legacy.contains("AssistantWideButton("))
        assertTrue(legacy.contains("AssistantTextInputField("))
        assertTrue(legacy.contains("AssistantSegmentedSelector("))
        assertTrue(legacy.contains("PersonalInfoGender.values().map"))

        forbiddenLegacyImplementationTokens.forEach { token ->
            assertFalse("Shared form input implementation must not return to legacy file: $token", legacy.contains(token))
        }
        expectedComponentTokens.forEach { token ->
            assertTrue("Assistant form input component is missing: $token", component.contains(token))
        }
        bannedComponentDependencies.forEach { dependency ->
            assertFalse(
                "Pure form input component must not depend on runtime/business dependency: $dependency",
                component.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyImplementationTokens = listOf(
            "Brush.verticalGradient(",
            "BasicTextField(",
            "KeyboardOptions(",
            "heightIn(min = 52.dp)",
            "PersonalInfoGender.values().forEach",
            "option.displayLabel(),"
        )

        val expectedComponentTokens = listOf(
            "internal fun AssistantWideButton(",
            "internal fun AssistantTextInputField(",
            "internal fun <T> AssistantSegmentedSelector(",
            "internal data class AssistantSegmentedSelectorItem",
            "BasicTextField(",
            "Brush.verticalGradient("
        )

        val bannedComponentDependencies = listOf(
            "PersonalInfoGender",
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
