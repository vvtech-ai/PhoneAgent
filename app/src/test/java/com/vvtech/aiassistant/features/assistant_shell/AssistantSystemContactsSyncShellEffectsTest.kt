package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSystemContactsSyncShellEffectsTest {
    @Test
    fun rootDelegatesSystemContactsSyncEffectsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantSystemContactsSyncShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPrimaryShellEffects("))
        assertFalse(root.contains("AssistantSystemContactsSyncShellEffects("))
        assertFalse(root.contains("AssistantSystemContactsSyncShellEffectsArgs("))
        assertTrue(primaryShell.contains("AssistantSystemContactsSyncShellEffects("))
        assertTrue(primaryShell.contains("AssistantSystemContactsSyncShellEffectsArgs("))
        assertTrue(primaryShell.contains("context = context"))
        assertTrue(primaryShell.contains("lifecycleOwner = lifecycleOwner"))
        assertTrue(primaryShell.contains("contactsPermissionGranted = state.permissionOverlay.contactsPermissionGranted"))
        assertTrue(primaryShell.contains("mockLoggedIn = runtime.auth.mockLoggedIn"))
        assertTrue(primaryShell.contains("onRefreshDeviceContacts = { runtime.contact.refreshDeviceContacts() }"))
        assertFalse(root.contains("FinalSystemContactsSyncEffects("))

        assertTrue(shell.contains("class AssistantSystemContactsSyncShellEffectsArgs"))
        assertTrue(shell.contains("fun AssistantSystemContactsSyncShellEffects"))
        assertTrue(shell.contains("FinalSystemContactsSyncEffects("))
        assertTrue(shell.contains("contactsPermissionGranted = args.contactsPermissionGranted"))
        assertTrue(shell.contains("onRefreshDeviceContacts = args.onRefreshDeviceContacts"))
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
