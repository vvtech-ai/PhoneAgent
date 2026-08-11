package com.vvtech.aiassistant.features.assistant_conversation.ui.overlay

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.V88LogoutConfirmDialog

@Composable
fun AssistantLogoutConfirmOverlay(
    visible: Boolean,
    onConfirm: () -> Unit,
    onCancel: () -> Unit
) {
    if (!visible) {
        return
    }

    V88LogoutConfirmDialog(
        onConfirm = onConfirm,
        onCancel = onCancel
    )
}
