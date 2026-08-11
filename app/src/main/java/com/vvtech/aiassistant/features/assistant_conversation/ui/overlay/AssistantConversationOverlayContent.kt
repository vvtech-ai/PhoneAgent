package com.vvtech.aiassistant.features.assistant_conversation.ui.overlay

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationAction
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationUiState

@Composable
fun AssistantConversationOverlayContent(
    state: AssistantConversationUiState,
    onAction: (AssistantConversationAction) -> Unit,
    modifier: Modifier = Modifier
) {
    @Suppress("UNUSED_EXPRESSION")
    state
    @Suppress("UNUSED_EXPRESSION")
    onAction
    @Suppress("UNUSED_EXPRESSION")
    modifier
}
