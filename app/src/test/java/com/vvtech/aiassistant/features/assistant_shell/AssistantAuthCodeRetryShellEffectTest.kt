package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAuthCodeRetryShellEffectTest {
    @Test
    fun rootDelegatesAuthCodeRetryEffectToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantAuthCodeRetryShellEffect.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPrimaryShellEffects("))
        assertFalse(root.contains("AssistantAuthCodeRetryShellEffect("))
        assertFalse(root.contains("AssistantAuthCodeRetryShellEffectArgs("))
        assertTrue(primaryShell.contains("AssistantAuthCodeRetryShellEffect("))
        assertTrue(primaryShell.contains("AssistantAuthCodeRetryShellEffectArgs("))
        assertTrue(primaryShell.contains("mockLoggedIn = runtime.auth.mockLoggedIn"))
        assertTrue(primaryShell.contains("authCodeRetrySeconds = runtime.auth.authCodeRetrySeconds"))
        assertTrue(primaryShell.contains("onRetrySecondsChange = runtime.auth::onRetrySecondsChange"))
        assertFalse(root.contains("FinalAuthCodeRetryEffect("))

        assertTrue(shell.contains("class AssistantAuthCodeRetryShellEffectArgs"))
        assertTrue(shell.contains("fun AssistantAuthCodeRetryShellEffect"))
        assertTrue(shell.contains("FinalAuthCodeRetryEffect("))
        assertTrue(shell.contains("mockLoggedIn = args.mockLoggedIn"))
        assertTrue(shell.contains("authCodeRetrySeconds = args.authCodeRetrySeconds"))
        assertTrue(shell.contains("onRetrySecondsChange = args.onRetrySecondsChange"))
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
