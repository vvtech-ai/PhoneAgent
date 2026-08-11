package com.vvtech.aiassistant.features.assistant_conversation.ui.page

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationAction
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationUiState
import com.vvtech.aiassistant.features.assistant_conversation.ui.components.AssistantConversationMessageList

@Composable
fun AssistantConversationMainPage(
    state: AssistantConversationUiState,
    onAction: (AssistantConversationAction) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        AssistantConversationMessageList(
            messages = state.conversation.messages,
            onAction = onAction
        )
    }
}
