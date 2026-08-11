package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantFinalResultPageBoundaryGuardTest {
    @Test
    fun finalResultPageDelegatesUiBodyToTaskBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalResultPage.kt")
        val componentFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/AssistantFinalResultPage.kt"
        )
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val component = componentFile.readText(Charsets.UTF_8)

        assertTrue("Legacy result page should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 80)
        assertTrue("Assistant final result page component must stay below the new-file guard threshold.", componentFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(legacy.contains("AssistantFinalResultPage("))
        assertTrue(legacy.contains("buildFinalResultPageState("))

        forbiddenLegacyImplementationTokens.forEach { token ->
            assertFalse("Final result UI implementation must not return to legacy file: $token", legacy.contains(token))
        }
        expectedComponentTokens.forEach { token ->
            assertTrue("Assistant final result component is missing: $token", component.contains(token))
        }
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Pure final result component must not depend on runtime/business dependency: $dependency",
                component.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyImplementationTokens = listOf(
            "LazyColumn(",
            "private fun FinalAiModelContactButton",
            "private fun FinalResultCard",
            "private fun FinalResultBadge",
            "private fun FinalResultInfoRow",
            "Icons.Outlined.ArrowBack",
            "TextOverflow.Ellipsis"
        )

        val expectedComponentTokens = listOf(
            "internal fun AssistantFinalResultPage(",
            "private fun AssistantFinalAiModelContactButton(",
            "private fun AssistantFinalResultCard(",
            "private fun AssistantFinalResultBadge(",
            "private fun AssistantFinalResultInfoRow(",
            "LazyColumn("
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
