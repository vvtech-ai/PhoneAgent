package com.vvtech.aiassistant.features.assistant_ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantPageChromeComponentsBoundaryGuardTest {
    @Test
    fun sharedPageChromeImplementationStaysInUiBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalSharedFormComponents.kt")
        val componentFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantPageChromeComponents.kt")
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val component = componentFile.readText(Charsets.UTF_8)

        assertTrue("Legacy shared form file should stay below the transition-file guard threshold.", legacyFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue("Assistant page chrome component file must stay below the new-file guard threshold.", componentFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy shared form file should delegate migrated chrome components to assistant_ui.",
            legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantScreenTopBar") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantBackTitleBar") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantBackIconBar") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantStopButton") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantFlowTitle") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantAiLoadingBubble") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantMetricCard") &&
                legacy.contains("AssistantScreenTopBar(title = title") &&
                legacy.contains("AssistantBackTitleBar(title = title") &&
                legacy.contains("AssistantBackIconBar(onBack = onBack") &&
                legacy.contains("AssistantStopButton(onClick = onClick)") &&
                legacy.contains("AssistantFlowTitle(text = text)") &&
                legacy.contains("AssistantAiLoadingBubble(modifier = modifier)") &&
                legacy.contains("AssistantMetricCard(label = label")
        )
        forbiddenLegacyImplementationTokens.forEach { token ->
            assertFalse("Page chrome implementation must not return to FinalSharedFormComponents: $token", legacy.contains(token))
        }
        expectedComponentTokens.forEach { token ->
            assertTrue("Assistant page chrome component is missing: $token", component.contains(token))
        }
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Pure page chrome component must not depend on runtime/business dependency: $dependency",
                component.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyImplementationTokens = listOf(
            "val transition = rememberInfiniteTransition",
            "clarifyLoadingAlpha",
            "Text(text = \"✦\"",
            "Color(0xDB111111), RoundedCornerShape(3.dp)",
            "Color.White.copy(alpha = 0.80f)",
            "lineHeight = 32.sp",
            "fontSize = 31.sp",
            "fontSize = 28.sp"
        )

        val expectedComponentTokens = listOf(
            "internal fun AssistantScreenTopBar(",
            "internal fun AssistantFlowTopBar(",
            "internal fun AssistantBackTitleBar(",
            "internal fun AssistantBackIconBar(",
            "internal fun AssistantStopButton(",
            "internal fun AssistantFlowTitle(",
            "internal fun AssistantAiLoadingBubble(",
            "internal fun AssistantMetricCard("
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
