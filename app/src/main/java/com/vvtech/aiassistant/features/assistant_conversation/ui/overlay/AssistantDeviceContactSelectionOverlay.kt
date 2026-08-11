package com.vvtech.aiassistant.features.assistant_conversation.ui.overlay

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.AgentDeviceContactSelectionSheet
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState

@Composable
fun AssistantDeviceContactSelectionOverlay(
    state: DeviceContactSelectionUiState?,
    onConfirm: (Map<String, DeviceContactSelectionCandidateUi>) -> Unit,
    onCancel: () -> Unit
) {
    state ?: return

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onCancel() },
        contentAlignment = Alignment.BottomCenter
    ) {
        Box(
            modifier = Modifier
                .padding(horizontal = 12.dp, vertical = 16.dp)
                .clickable(enabled = false) {}
        ) {
            AgentDeviceContactSelectionSheet(
                state = state,
                onConfirm = onConfirm,
                onCancel = onCancel
            )
        }
    }
}
