package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootPageHostSecondaryArgsFactoryTest {
    @Test
    fun rootDelegatesSecondaryPageHostArgsAssemblyToFactory() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostSecondaryArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("buildAssistantRootHostArgs("))
        assertFalse(root.contains("buildAssistantRootPageHostSecondaryArgs("))
        assertFalse(root.contains("AssistantRootPageHostSecondaryArgsFactoryDeps("))
        assertTrue(hostShell.contains("buildAssistantRootPageHostSecondaryArgs("))
        assertTrue(hostShell.contains("AssistantRootPageHostSecondaryArgsFactoryDeps("))
        assertTrue(hostShell.contains("settings = pageHostSecondaryArgs.settings"))
        assertTrue(hostShell.contains("permissionDeveloper = pageHostSecondaryArgs.permissionDeveloper"))

        secondaryBuilderInputs.forEach { inputName ->
            assertFalse("$inputName must stay out of AssistantRootScreen", root.contains("$inputName("))
            assertTrue("$inputName must stay in the shell factory", factory.contains("$inputName("))
        }
        assertFalse(root.contains("SettingsMainInput("))
        assertFalse(root.contains("ProviderSettingsCallbacksInput("))
        assertFalse(root.contains("ClarifyConfirmCallbacksInput("))
        assertFalse(root.contains("AssistantPermissionDeveloperCallbacks("))

        assertTrue(factory.contains("AssistantRootPageHostSecondaryRuntimeDeps("))
        assertTrue(factory.contains("AssistantRootPageHostSecondaryStateDeps("))
        assertTrue(factory.contains("AssistantRootPageHostSecondaryValueDeps("))
        assertTrue(factory.lines().size <= 300)
        assertTrue(root.lines().size < 1100)
        assertTrue(hostShell.lines().size <= 300)
    }

    private companion object {
        val secondaryBuilderInputs = listOf(
            "AssistantSettingsArgsBuilderInput",
            "AssistantProviderSettingsArgsBuilderInput",
            "AssistantVoiceCloneArgsBuilderInput",
            "AssistantClarifyConfirmArgsBuilderInput",
            "AssistantPermissionDeveloperArgsBuilderInput"
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
