package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant_ui.AssistantConfirmationDialog

@Composable
internal fun CrossBorderTranslationCallDialog(
    visible: Boolean,
    onCancel: () -> Unit,
    onContinue: () -> Unit
) {
    if (!visible) return
    AssistantConfirmationDialog(
        title = stringResource(R.string.cross_border_title),
        message = stringResource(R.string.cross_border_message),
        dismissLabel = stringResource(R.string.common_cancel),
        confirmLabel = stringResource(R.string.cross_border_continue),
        onDismiss = onCancel,
        onConfirm = onContinue
    )
}
