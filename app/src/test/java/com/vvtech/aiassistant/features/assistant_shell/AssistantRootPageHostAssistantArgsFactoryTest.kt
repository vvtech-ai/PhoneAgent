package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootPageHostAssistantArgsFactoryTest {
    @Test
    fun rootDelegatesAssistantPageHostArgsAssemblyToFactory() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("buildAssistantRootHostArgs("))
        assertFalse(root.contains("buildAssistantRootPageHostAssistantArgs("))
        assertFalse(root.contains("AssistantRootPageHostAssistantArgsFactoryDeps("))
        assertTrue(hostShell.contains("buildAssistantRootPageHostAssistantArgs("))
        assertTrue(hostShell.contains("AssistantRootPageHostAssistantArgsFactoryDeps("))
        assertTrue(hostShell.contains("assistant = pageHostAssistantArgs"))

        assistantBuilderInputs.forEach { inputName ->
            assertFalse("$inputName must stay out of AssistantRootScreen", root.contains("$inputName("))
            assertTrue("$inputName must stay in the shell factory", factory.contains("$inputName("))
        }
        assertFalse(root.contains("buildAssistantConversationArgs("))
        assertTrue(factory.contains("buildAssistantConversationArgs("))

        assertTrue(root.contains("onStartVoiceEntry = {"))
        assertTrue(
            root.contains(
                "rootActionGraph.startVoiceEntry(startWithVoice = true, resumeExisting = false)"
            )
        )
        assertTrue(factory.contains("onInterruptTts = assistantViewModel::onTtsInterrupted"))
        assertTrue(factory.contains("launchAssistantAgentDocumentPicker("))
        assertTrue(factory.contains("cancelAssistantAgentDocumentPicker("))
        assertTrue(factory.contains("AssistantHomeNotificationReadActions.dismissCurrent("))
        assertTrue(factory.contains("onStartVoiceInteractionWithPermission = callbacks.onStartVoiceInteractionWithPermission"))

        assertTrue(factory.lines().size <= 300)
        assertTrue(root.lines().size < 1100)
        assertTrue(hostShell.lines().size <= 300)
    }

    private companion object {
        val assistantBuilderInputs = listOf(
            "AssistantConversationArgsBuilderInput",
            "AssistantConversationCoreInput",
            "AssistantConversationCallbacksInput",
            "AssistantConversationAgentInput",
            "AssistantConversationNotificationInput",
            "AssistantConversationSingleFlowInput"
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
