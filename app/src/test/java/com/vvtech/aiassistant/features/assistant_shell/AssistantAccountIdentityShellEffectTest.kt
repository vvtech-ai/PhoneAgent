package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAccountIdentityShellEffectTest {
    @Test
    fun rootDelegatesAccountIdentityEffectToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantAccountIdentityShellEffect.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPrimaryShellEffects("))
        assertFalse(root.contains("AssistantAccountIdentityShellEffect("))
        assertFalse(root.contains("AssistantAccountIdentityShellEffectArgs("))
        assertTrue(primaryShell.contains("AssistantAccountIdentityShellEffect("))
        assertTrue(primaryShell.contains("AssistantAccountIdentityShellEffectArgs("))
        assertTrue(primaryShell.contains("onLoadCallRecordsForAccount = state.callRecord::loadForAccount"))
        assertTrue(primaryShell.contains("onClearCallRecordsForCurrentAccount = {"))
        assertTrue(primaryShell.contains("assistantViewModel::onAccountIdentityChanged"))
        assertFalse(root.contains("FinalAccountIdentityEffect("))
        assertFalse(root.contains("FinalAccountIdentityEffectArgs("))

        assertTrue(shell.contains("class AssistantAccountIdentityShellEffectArgs"))
        assertTrue(shell.contains("fun AssistantAccountIdentityShellEffect"))
        assertTrue(shell.contains("FinalAccountIdentityEffect("))
        assertTrue(shell.contains("FinalAccountIdentityEffectArgs("))
        assertTrue(shell.contains("onClearCallRecordsForCurrentAccount = args.onClearCallRecordsForCurrentAccount"))
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
