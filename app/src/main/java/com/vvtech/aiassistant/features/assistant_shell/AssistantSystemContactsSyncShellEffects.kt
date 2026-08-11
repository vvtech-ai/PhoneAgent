package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.lifecycle.LifecycleOwner
import com.vvtech.aiassistant.features.assistant.FinalSystemContactsSyncEffects

internal data class AssistantSystemContactsSyncShellEffectsArgs(
    val context: Context,
    val lifecycleOwner: LifecycleOwner,
    val contactsPermissionGranted: Boolean,
    val mockLoggedIn: Boolean,
    val onRefreshDeviceContacts: () -> Unit
)

@Composable
internal fun AssistantSystemContactsSyncShellEffects(args: AssistantSystemContactsSyncShellEffectsArgs) {
    FinalSystemContactsSyncEffects(
        context = args.context,
        lifecycleOwner = args.lifecycleOwner,
        contactsPermissionGranted = args.contactsPermissionGranted,
        mockLoggedIn = args.mockLoggedIn,
        onRefreshDeviceContacts = args.onRefreshDeviceContacts
    )
}
