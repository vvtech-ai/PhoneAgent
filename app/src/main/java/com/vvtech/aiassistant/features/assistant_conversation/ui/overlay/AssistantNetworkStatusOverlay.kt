package com.vvtech.aiassistant.features.assistant_conversation.ui.overlay

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88NetworkStatusLayer

@Composable
internal fun AssistantNetworkStatusOverlay(
    mode: V88NetworkMode,
    blocking: Boolean,
    onRetry: () -> Unit,
    onDismissBlocker: () -> Unit
) {
    V88NetworkStatusLayer(
        mode = mode,
        blocking = blocking,
        onRetry = onRetry,
        onDismissBlocker = onDismissBlocker
    )
}
