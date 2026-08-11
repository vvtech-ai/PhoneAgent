package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class TaskRestoreStateHolder(
    private val conversationList: MutableStateFlow<List<ConversationListItem>>
) {

    fun updateConversationCardStatus(
        sessionId: String,
        status: String
    ) {
        conversationList.update {
            TaskRestoreStateReducer.updateConversationCardStatus(it, sessionId, status)
        }
    }
}
