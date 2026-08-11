package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAgentPermissionShellEffectTest {
    @Test
    fun rootDelegatesAgentPermissionEffectToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantAgentPermissionShellEffect.kt"
            ).readText(Charsets.UTF_8)
        val secondaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootSecondaryShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootSecondaryShellEffects("))
        assertFalse(root.contains("AssistantAgentPermissionShellEffect("))
        assertFalse(root.contains("AssistantAgentPermissionShellEffectArgs("))
        assertTrue(secondaryShell.contains("AssistantAgentPermissionShellEffect("))
        assertTrue(secondaryShell.contains("AssistantAgentPermissionShellEffectArgs("))
        assertTrue(secondaryShell.contains("agentPermissionRequest = assistantUiState.agentPermissionRequest"))
        assertTrue(secondaryShell.contains("agentPendingToolCallId = assistantUiState.agentPendingToolCallId"))
        assertTrue(secondaryShell.contains("isAgentPermissionGranted = { request -> isAssistantAgentPermissionGranted(context, request) }"))
        assertTrue(secondaryShell.contains("onAgentPermissionResult = assistantViewModel::onAgentPermissionResult"))
        assertTrue(
            secondaryShell.contains(
                "onActiveAgentPermissionRequestChange = state.transientOverlay::updateActiveAgentPermissionRequest"
            )
        )
        assertTrue(secondaryShell.contains("onLaunchPermission = { args.rootActivityLaunchers.agentPermission.launch(it) }"))
        assertFalse(root.contains("FinalAgentPermissionEffect("))
        assertFalse(root.contains("AssistantAgentPermissionEffectArgs("))

        val identityIndex = secondaryShell.indexOf("AssistantIdentityInitOverlayShellEffect(")
        val agentPermissionIndex = secondaryShell.indexOf("AssistantAgentPermissionShellEffect(")
        val trustedCalleeIndex = secondaryShell.indexOf("AssistantTrustedCalleeRuntimeShellEffect(")
        assertTrue(identityIndex >= 0)
        assertTrue(agentPermissionIndex > identityIndex)
        assertTrue(trustedCalleeIndex > agentPermissionIndex)

        assertTrue(shell.contains("class AssistantAgentPermissionShellEffectArgs"))
        assertTrue(shell.contains("fun AssistantAgentPermissionShellEffect"))
        assertTrue(shell.contains("FinalAgentPermissionEffect("))
        assertTrue(shell.contains("AssistantAgentPermissionEffectArgs("))
        assertTrue(shell.contains("agentPermissionRequest = args.agentPermissionRequest"))
        assertTrue(shell.contains("onLaunchPermission = args.onLaunchPermission"))
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
