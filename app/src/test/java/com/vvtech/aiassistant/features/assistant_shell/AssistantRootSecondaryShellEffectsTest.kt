package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootSecondaryShellEffectsTest {
    @Test
    fun secondaryEffectsOwnPostAuthRootEffectWiring() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val secondaryShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootSecondaryShellEffects.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootSecondaryShellEffects("))
        assertTrue(root.contains("AssistantRootSecondaryShellEffectsArgs("))
        assertTrue(secondaryShell.contains("internal data class AssistantRootSecondaryShellEffectsArgs("))
        assertTrue(secondaryShell.contains("internal fun AssistantRootSecondaryShellEffects("))

        secondaryEffectTokens.forEach { token ->
            assertFalse("$token must not return to AssistantRootScreen", root.contains(token))
            assertTrue("$token must be owned by AssistantRootSecondaryShellEffects", secondaryShell.contains(token))
        }

        val startupIndex = secondaryShell.indexOf("AssistantRootStartupEffect(")
        val identityIndex = secondaryShell.indexOf("AssistantIdentityInitOverlayShellEffect(")
        val agentPermissionIndex = secondaryShell.indexOf("AssistantAgentPermissionShellEffect(")
        val trustedCalleeIndex = secondaryShell.indexOf("AssistantTrustedCalleeRuntimeShellEffect(")
        val aiCallIndex = secondaryShell.indexOf("AssistantAiCallPageSyncEffect(")
        assertTrue(startupIndex >= 0)
        assertTrue(identityIndex > startupIndex)
        assertTrue(agentPermissionIndex > identityIndex)
        assertTrue(trustedCalleeIndex > agentPermissionIndex)
        assertTrue(aiCallIndex > trustedCalleeIndex)

        assertTrue(secondaryShell.lines().size <= 140)
        assertTrue(sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readLines(Charsets.UTF_8).size < 360)
    }

    private companion object {
        val secondaryEffectTokens = listOf(
            "AssistantRootStartupEffect(",
            "AssistantIdentityInitOverlayShellEffect(",
            "AssistantAgentPermissionShellEffect(",
            "AssistantTrustedCalleeRuntimeShellEffect(",
            "AssistantAiCallPageSyncEffect("
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
