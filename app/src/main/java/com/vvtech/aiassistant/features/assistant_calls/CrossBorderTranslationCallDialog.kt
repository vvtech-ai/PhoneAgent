package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_ui.AssistantConfirmationDialog

@Composable
internal fun CrossBorderTranslationCallDialog(
    visible: Boolean,
    onCancel: () -> Unit,
    onContinue: () -> Unit
) {
    if (!visible) return
    AssistantConfirmationDialog(
        title = "跨境通话质量提示",
        message = "当前为跨境实时翻译通话，可能出现信号不稳定或延迟较大的情况。",
        dismissLabel = "取消",
        confirmLabel = "仍要继续",
        onDismiss = onCancel,
        onConfirm = onContinue
    )
}
