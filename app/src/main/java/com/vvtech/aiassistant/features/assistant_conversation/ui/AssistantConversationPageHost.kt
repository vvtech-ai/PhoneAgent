package com.vvtech.aiassistant.features.assistant_conversation.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationAction
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationUiState
import com.vvtech.aiassistant.features.assistant_conversation.ui.page.AssistantConversationMainPage

@Composable
fun AssistantConversationPageHost(
    state: AssistantConversationUiState,
    onAction: (AssistantConversationAction) -> Unit,
    modifier: Modifier = Modifier
) {
    AssistantConversationMainPage(
        state = state,
        onAction = onAction,
        modifier = modifier
    )
}
