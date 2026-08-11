package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootContactPermissionRuntimeShellTest {
    @Test
    fun rootDelegatesContactPermissionAndAgentLookupRuntimeToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val shell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootContactPermissionRuntimeShell.kt"
        ).readText(Charsets.UTF_8)
        val permissionRuntime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPermissionRuntimeShell.kt"
        ).readText(Charsets.UTF_8)
        val actionGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("rememberAssistantRootPermissionRuntime("))
        assertTrue(root.contains("val contactPermissionLaunchers = permissionRuntime.contactPermissionLaunchers"))
        assertFalse(root.contains("rememberAssistantRootContactPermissionRuntime("))
        assertFalse(root.contains("AssistantRootContactPermissionRuntimeDeps("))
        assertFalse(root.contains("val contactPermissionLaunchers = contactPermissionRuntime.launchers"))
        assertFalse(root.contains("contactPermissionLaunchers.contacts.launch"))
        assertFalse(actionGraph.contains("deps.contactPermissionLaunchers.contacts.launch"))
        assertTrue(actionGraph.contains("permissionName = V88PermissionKind.Contacts.name"))
        assertTrue(root.contains("contactPermission = contactPermissionLaunchers"))

        rootForbiddenTokens.forEach { token ->
            assertFalse("$token must not return to AssistantRootScreen", root.contains(token))
        }
        shellOwnedTokens.forEach { token ->
            assertTrue("$token must be owned by contact permission runtime shell", shell.contains(token))
        }

        assertTrue(shell.contains("internal class AssistantRootContactPermissionRuntime("))
        assertTrue(shell.contains("rememberAssistantContactPermissionLaunchers("))
        assertTrue(shell.contains("AssistantContactPermissionLauncherCallbacks("))
        assertTrue(shell.contains("contactRuntime.refreshDeviceContacts()"))
        assertTrue(shell.contains("contactRuntime.refreshDeviceContacts {"))
        assertTrue(shell.contains("contactRuntime.clearContactRecords()"))
        assertFalse(shell.contains("navigationState.goHome(resetPrevious = false)"))
        assertTrue(shell.contains("navigationState.applyMainTab(FinalMainTab.Contacts)"))
        assertTrue(shell.contains("resolveContactPermissionResult(granted, shouldShowRationale)"))
        assertTrue(shell.contains("AssistantContactPermissionSettingsDialog("))
        assertTrue(shell.contains("onLaunchContactsPermission = { contactPermissionLaunchers.agentContacts.launch(it) }"))
        assertTrue(shell.contains("onAgentLookupContactResult = deps.assistantViewModel::onAgentLookupContactResult"))
        assertTrue(shell.contains("deps.assistantViewModel.internalUiState.value.agentPendingToolCallId"))
        assertTrue(shell.contains("deps.assistantViewModel.onAgentLookupDeviceContactsResolved("))
        assertTrue(shell.lines().size <= 300)
        assertTrue(permissionRuntime.contains("rememberAssistantRootContactPermissionRuntime("))
        assertTrue(permissionRuntime.contains("AssistantRootContactPermissionRuntimeDeps("))
        assertTrue(permissionRuntime.contains("contactPermissionLaunchers = contactPermissionRuntime.launchers"))
        assertTrue(permissionRuntime.lines().size <= 300)
        assertTrue(root.lines().size < 1000)
    }

    private companion object {
        val rootForbiddenTokens = listOf(
            "rememberAssistantAgentContactLookupState()",
            "rememberAssistantContactPermissionLaunchers(",
            "AssistantAgentContactLookupEffects(",
            "markPermissionRetry()",
            "需要通讯录权限才能使用此功能",
            "contactRuntime.clearContactRecords()",
            "onAgentLookupContactResult = assistantViewModel::onAgentLookupContactResult",
            "assistantViewModel.onAgentLookupDeviceContactsResolved("
        )

        val shellOwnedTokens = listOf(
            "rememberAssistantAgentContactLookupState()",
            "rememberAssistantContactPermissionLaunchers(",
            "AssistantAgentContactLookupEffects(",
            "markPermissionRetry()",
            "需要通讯录权限才能使用此功能",
            "contactRuntime.clearContactRecords()",
            "onAgentLookupContactResult = deps.assistantViewModel::onAgentLookupContactResult",
            "deps.assistantViewModel.onAgentLookupDeviceContactsResolved("
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
