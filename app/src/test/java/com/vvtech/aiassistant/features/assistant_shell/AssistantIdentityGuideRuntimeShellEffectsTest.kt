package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantIdentityGuideRuntimeShellEffectsTest {
    @Test
    fun rootDelegatesIdentityGuideRuntimeEffectsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantIdentityGuideRuntimeShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val secondaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootSecondaryShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootSecondaryShellEffects("))
        assertFalse(root.contains("AssistantIdentityInitOverlayShellEffect("))
        assertFalse(root.contains("AssistantIdentityInitOverlayShellEffectArgs("))
        assertFalse(root.contains("AssistantTrustedCalleeRuntimeShellEffect("))
        assertFalse(root.contains("AssistantTrustedCalleeRuntimeShellEffectArgs("))
        assertTrue(secondaryShell.contains("AssistantIdentityInitOverlayShellEffect("))
        assertTrue(secondaryShell.contains("AssistantIdentityInitOverlayShellEffectArgs("))
        assertTrue(secondaryShell.contains("AssistantTrustedCalleeRuntimeShellEffect("))
        assertTrue(secondaryShell.contains("AssistantTrustedCalleeRuntimeShellEffectArgs("))
        assertTrue(secondaryShell.contains("identityInitOverlayVisible = assistantUiState.identityInitOverlayVisible"))
        assertTrue(secondaryShell.contains("runtime = runtime.contact"))
        assertTrue(secondaryShell.contains("runtime = runtime.auth"))
        assertTrue(secondaryShell.contains("navigationState.applyMainTab(fallbackTab, fallbackPage)"))
        assertFalse(root.contains("FinalIdentityInitOverlayEffect("))
        assertFalse(root.contains("FinalTrustedCalleeRuntimeEffect("))

        val identityIndex = secondaryShell.indexOf("AssistantIdentityInitOverlayShellEffect(")
        val agentPermissionIndex = secondaryShell.indexOf("AssistantAgentPermissionShellEffect(")
        val trustedCalleeIndex = secondaryShell.indexOf("AssistantTrustedCalleeRuntimeShellEffect(")
        assertTrue(identityIndex >= 0)
        assertTrue(agentPermissionIndex > identityIndex)
        assertTrue(trustedCalleeIndex > agentPermissionIndex)

        assertTrue(shell.contains("fun AssistantIdentityInitOverlayShellEffect"))
        assertTrue(shell.contains("fun AssistantTrustedCalleeRuntimeShellEffect"))
        assertTrue(shell.contains("FinalIdentityInitOverlayEffect("))
        assertTrue(shell.contains("AssistantIdentityInitOverlayEffectArgs("))
        assertTrue(shell.contains("FinalTrustedCalleeRuntimeEffect("))
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
