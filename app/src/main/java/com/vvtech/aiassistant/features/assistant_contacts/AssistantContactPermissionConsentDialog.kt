package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_ui.AssistantConfirmationDialog

internal object AssistantContactPermissionDialogText {
    val title: String
        get() = currentAppText("允许访问通讯录？", "Allow Contacts Access?")
    val description: String
        get() = currentAppText(
            "用于选择联系人并发起通话任务",
            "Used to select contacts and start calling tasks"
        )
    val allow: String
        get() = currentAppText("继续授权", "Continue")
    val deny: String
        get() = currentAppText("暂不", "Not Now")
}

@Composable
internal fun AssistantContactPermissionConsentDialog(
    onAllow: () -> Unit,
    onDeny: () -> Unit
) {
    AssistantConfirmationDialog(
        title = AssistantContactPermissionDialogText.title,
        message = AssistantContactPermissionDialogText.description,
        dismissLabel = AssistantContactPermissionDialogText.deny,
        confirmLabel = AssistantContactPermissionDialogText.allow,
        onDismiss = onDeny,
        onConfirm = onAllow
    )
}
