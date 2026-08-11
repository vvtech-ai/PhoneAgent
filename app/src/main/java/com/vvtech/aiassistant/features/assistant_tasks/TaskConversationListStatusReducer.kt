package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem

internal object TaskConversationListStatusReducer {
    fun updateStatus(
        conversations: List<ConversationListItem>,
        sessionId: String,
        status: String
    ): List<ConversationListItem> {
        return conversations.map { item ->
            if (item.sessionId == sessionId) {
                item.copy(
                    title = item.title.orEmpty(),
                    status = status
                )
            } else {
                item
            }
        }
    }
}
