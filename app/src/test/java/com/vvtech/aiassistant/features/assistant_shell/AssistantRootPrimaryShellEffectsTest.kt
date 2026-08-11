package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootPrimaryShellEffectsTest {
    @Test
    fun primaryEffectsOwnTopLevelRootEffectWiring() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val primaryShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPrimaryShellEffects("))
        assertTrue(root.contains("AssistantRootPrimaryShellEffectsArgs("))
        assertTrue(primaryShell.contains("internal data class AssistantRootPrimaryShellEffectsArgs("))
        assertTrue(primaryShell.contains("internal fun AssistantRootPrimaryShellEffects("))

        primaryEffectTokens.forEach { token ->
            assertFalse("$token must not return to AssistantRootScreen", root.contains(token))
            assertTrue("$token must be owned by AssistantRootPrimaryShellEffects", primaryShell.contains(token))
        }
        assertTrue(primaryShell.lines().size <= 180)
        assertTrue(sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readLines(Charsets.UTF_8).size < 400)
    }

    private companion object {
        val primaryEffectTokens = listOf(
            "AssistantVoiceLifecycleShellEffects(",
            "AssistantPageLifecycleShellEffects(",
            "AssistantAuthCodeRetryShellEffect(",
            "AssistantAccountIdentityShellEffect(",
            "AssistantSystemContactsSyncShellEffects(",
            "AssistantBackNavigationEffect(",
            "AssistantPageResourceShellEffects(",
            "AssistantTranslationRuntimeShellEffects(",
            "AssistantSingleFlowBackgroundShellEffect("
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
