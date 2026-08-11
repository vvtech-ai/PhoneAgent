package com.vvtech.aiassistant.features.assistant_conversation.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationAction
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationUiState

@Composable
fun AssistantConversationScreen(
    state: AssistantConversationUiState,
    onAction: (AssistantConversationAction) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        AssistantConversationPageHost(
            state = state,
            onAction = onAction
        )
        AssistantConversationOverlayHost(
            state = state,
            onAction = onAction
        )
    }
}
