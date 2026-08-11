package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootActionGraphTest {
    @Test
    fun rootConsumesActionGraphAndGraphOwnsActionConstructors() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val graph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("buildAssistantRootActionGraph("))
        assertTrue(root.contains("AssistantRootActionGraphDeps("))
        assertTrue(root.contains("val voiceEntryRootActions = rootActionGraph.voiceEntry"))
        assertTrue(root.contains("val callEntryActions = rootActionGraph.callEntry"))
        assertTrue(root.contains("val rootNavigationActions = rootActionGraph.navigation"))
        assertTrue(root.contains("val rootTaskFlowActions = rootActionGraph.taskFlow"))
        assertTrue(root.contains("rootActionGraph.startVoiceEntry("))
        assertTrue(root.contains("rootActionGraph.startVoiceInteractionWithPermission("))
        assertTrue(root.contains("blockIfOffline = rootActionGraph::blockIfOffline"))
        assertFalse(root.contains("rootActionGraph::blockAssistantEntryIfIdentityIncomplete"))

        val constructorTokens = listOf(
            "AssistantVoiceEntryRootActions(",
            "AssistantVoiceEntryRootActionDeps(",
            "AssistantVoiceEntryRootFlowCallbacks(",
            "AssistantVoiceEntryRootDispatchCallbacks(",
            "AssistantRootCallEntryActions(",
            "AssistantRootCallEntryActionDeps(",
            "AssistantRootNavigationActions(",
            "AssistantRootNavigationActionDeps(",
            "AssistantRootTaskFlowActions(",
            "AssistantRootTaskFlowActionDeps("
        )
        constructorTokens.forEach { token ->
            assertFalse("$token must stay out of AssistantRootScreen", root.contains(token))
            assertTrue("$token must be owned by AssistantRootActionGraph", graph.contains(token))
        }

        assertTrue(graph.contains("class AssistantRootActionGraph("))
        assertTrue(graph.contains("fun blockIfOffline()"))
        assertFalse(graph.contains("fun blockAssistantEntryIfIdentityIncomplete()"))
        assertFalse(graph.contains("runtime.contact.blockAssistantEntryIfIdentityIncomplete()"))
        assertTrue(graph.contains("fun startVoiceEntry("))
        assertTrue(graph.contains("fun startVoiceInteractionWithPermission("))
        assertTrue(graph.contains("clearAssistantRootLocalTaskItemsForRequirementEntry("))
        assertTrue(graph.contains("clearAssistantRootPendingVoiceEntryState("))
        assertTrue(root.lines().size < 650)
        assertTrue(graph.lines().size <= 300)
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
