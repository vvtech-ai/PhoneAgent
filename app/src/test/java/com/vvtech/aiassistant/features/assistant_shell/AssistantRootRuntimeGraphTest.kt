package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootRuntimeGraphTest {
    @Test
    fun rootRuntimeGraphOwnsRootRuntimeAndStateCreation() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val graphFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt"
        )
        val graph = graphFile.readText(Charsets.UTF_8)

        assertTrue(root.contains("rememberAssistantRootRuntimeGraph("))
        assertTrue(root.contains("rootRuntimeGraph.environment.prefs"))
        assertTrue(root.contains("rootRuntimeGraph.state.navigation"))
        assertTrue(root.contains("rootRuntimeGraph.runtime.voiceClone"))

        rootRuntimeCreationTokens.forEach { token ->
            assertFalse("$token must not return to AssistantRootScreen", root.contains(token))
            assertTrue("$token must be owned by runtime graph", graph.contains(token))
        }
        rootStateCreationTokens.forEach { token ->
            assertFalse("$token must not return to AssistantRootScreen", root.contains(token))
            assertTrue("$token must be owned by runtime graph", graph.contains(token))
        }
        assertTrue(graph.contains("AssistantRootRuntimeEnvironment("))
        assertTrue(graph.contains("AssistantRootStateGraph("))
        assertTrue(graph.contains("AssistantRootControllerGraph("))
        assertTrue(graphFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(root.lines().size < 800)
    }

    private companion object {
        val rootRuntimeCreationTokens = listOf(
            "remember { AppContainer.taskRepository }",
            "remember { AssistantContainer.repository }",
            "rememberAssistantVoiceCloneRuntimeController(",
            "rememberAssistantProviderRuntimeController(",
            "rememberAssistantAuthRuntimeController(",
            "rememberAssistantOtaRuntimeController(",
            "rememberAssistantLogUploadRuntimeController(",
            "rememberAssistantOutboundNumberRuntimeController(",
            "rememberAssistantTaskRuntimeController(",
            "rememberAssistantContactRuntimeController(",
            "rememberAssistantContactAiModelRuntimeController(",
            "rememberAssistantTranslationCallRuntimeController("
        )

        val rootStateCreationTokens = listOf(
            "rememberAssistantNavigationState()",
            "rememberAssistantRootTransientOverlayState()",
            "rememberAssistantTaskPageRefreshState()",
            "rememberAssistantHomeNotificationReadState(prefs)",
            "rememberAssistantPermissionOverlayState(context)",
            "rememberAssistantSystemPhoneCallState()",
            "rememberAssistantHomeComposerState(ComposerMode.Voice.name)",
            "rememberAssistantRootSettingsPreferenceState(prefs)",
            "rememberAssistantCallRecordState(prefs)",
            "rememberAssistantCallDialState("
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
