package com.vvtech.aiassistant.features.assistant_shell

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable

internal class AssistantContactPermissionLaunchers(
    val contacts: ActivityResultLauncher<String>,
    val agentContacts: ActivityResultLauncher<String>
)

internal data class AssistantContactPermissionLauncherCallbacks(
    val onContactsPermissionResult: (Boolean) -> Unit,
    val onAgentContactsPermissionResult: (Boolean) -> Unit
)

@Composable
internal fun rememberAssistantContactPermissionLaunchers(
    callbacks: AssistantContactPermissionLauncherCallbacks
): AssistantContactPermissionLaunchers {
    val contacts = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = callbacks.onContactsPermissionResult
    )
    val agentContacts = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = callbacks.onAgentContactsPermissionResult
    )

    return AssistantContactPermissionLaunchers(
        contacts = contacts,
        agentContacts = agentContacts
    )
}
