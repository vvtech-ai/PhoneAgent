package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootHostArgsShellTest {
    @Test
    fun rootDelegatesFinalHostArgsAssemblyToHostShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)
        val contract = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsContract.kt"
        ).readText(Charsets.UTF_8)
        val assistantFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("buildAssistantRootHostArgs("))
        assertTrue(root.contains("AssistantRootHostArgsFactoryDeps("))
        assertTrue(root.contains("AssistantPageHost(hostArgs.pageHost)"))
        assertTrue(root.contains("AssistantOverlayHost(hostArgs.overlayHost)"))

        oldRootAssemblyTokens.forEach { token ->
            assertFalse("$token must not return to AssistantRootScreen", root.contains(token))
            assertTrue("$token must be owned by host shell", hostShell.contains(token))
        }
        assertFalse(root.contains("AssistantAgentDocumentPickerCallbacks("))
        assertTrue(hostShell.contains("AssistantAgentDocumentPickerCallbacks("))

        assertTrue(hostShell.contains("buildAssistantRootPageHostSecondaryArgs("))
        assertTrue(hostShell.contains("buildAssistantRootPageHostAssistantArgs("))
        assertTrue(hostShell.contains("buildAssistantRootPageHostMainArgs("))
        assertTrue(hostShell.contains("buildAssistantPageHostArgs("))
        assertTrue(hostShell.contains("buildAssistantRootOverlayArgs("))
        assertTrue(assistantFactory.contains("onInterruptTts = assistantViewModel::onTtsInterrupted"))
        assertTrue(hostShell.lines().size <= 300)
        assertTrue(contract.lines().size <= 150)
        assertTrue(root.lines().size < 1100)
    }

    private companion object {
        val oldRootAssemblyTokens = listOf(
            "AssistantRootPageHostSecondaryArgsFactoryDeps(",
            "AssistantRootPageHostAssistantArgsFactoryDeps(",
            "AssistantRootPageHostMainArgsFactoryDeps(",
            "AssistantPageHostArgsBuilderInput(",
            "AssistantRootOverlayArgsFactoryDeps("
        )

        fun sourceFile(path: String): File =
            listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
    }
}
