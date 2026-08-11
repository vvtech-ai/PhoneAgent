package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_ui.AssistantConfirmationDialog

internal object AssistantContactPermissionDialogText {
    const val title = "允许访问通讯录？"
    const val description = "用于选择联系人并发起通话任务"
    const val allow = "继续授权"
    const val deny = "暂不"
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
