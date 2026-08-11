package com.vvtech.aiassistant.features.assistant_conversation.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationAction
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationUiState
import com.vvtech.aiassistant.features.assistant_conversation.ui.overlay.AssistantConversationOverlayContent

@Composable
fun AssistantConversationOverlayHost(
    state: AssistantConversationUiState,
    onAction: (AssistantConversationAction) -> Unit,
    modifier: Modifier = Modifier
) {
    AssistantConversationOverlayContent(
        state = state,
        onAction = onAction,
        modifier = modifier
    )
}
