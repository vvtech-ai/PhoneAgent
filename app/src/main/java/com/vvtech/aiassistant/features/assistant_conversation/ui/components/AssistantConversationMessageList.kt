package com.vvtech.aiassistant.features.assistant_conversation.ui.components

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_conversation.contract.AssistantConversationAction
import com.vvtech.aiassistant.features.assistant_conversation.model.AssistantConversationMessageUi

@Composable
fun AssistantConversationMessageList(
    messages: List<AssistantConversationMessageUi>,
    onAction: (AssistantConversationAction) -> Unit
) {
    @Suppress("UNUSED_EXPRESSION")
    messages
    @Suppress("UNUSED_EXPRESSION")
    onAction
}
