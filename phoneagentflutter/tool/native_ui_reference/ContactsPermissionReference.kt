package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant.V88PermissionDialog
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import com.vvtech.aiassistant.features.assistant_shell.AssistantContactPermissionSettingsDialog

/** Actual fixed Compose dialogs, callbacks never request OS permission/settings. */
@Composable
fun ContactsPermissionReference(settings: Boolean) {
    PhoneFrameWithBackground {
        if (settings) AssistantContactPermissionSettingsDialog(onDismiss = {}, onOpenSettings = {})
        else V88PermissionDialog(V88PermissionKind.Contacts, onAllow = {}, onDeny = {})
    }
}
