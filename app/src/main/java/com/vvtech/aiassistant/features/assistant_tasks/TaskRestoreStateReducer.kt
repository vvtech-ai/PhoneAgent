package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem

internal object TaskRestoreStateReducer {
    fun updateConversationCardStatus(
        conversations: List<ConversationListItem>,
        sessionId: String,
        status: String
    ): List<ConversationListItem> {
        return TaskConversationListStatusReducer.updateStatus(conversations, sessionId, status)
    }
}
