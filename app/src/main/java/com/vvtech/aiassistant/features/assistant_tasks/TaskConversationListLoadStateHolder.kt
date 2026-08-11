package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.flow.MutableStateFlow

internal class TaskConversationListLoadStateHolder(
    private val conversationList: MutableStateFlow<List<ConversationListItem>>,
    private val conversationLoading: MutableStateFlow<Boolean>,
    private val conversationError: MutableStateFlow<String?>
) {
    fun isLoading(): Boolean {
        return conversationLoading.value
    }

    fun beginLoad() {
        conversationLoading.value = true
        conversationError.value = null
    }

    fun applyLoadedConversations(
        conversations: List<ConversationListItem>,
        pendingExecutionErrorExitSessions: Set<String>,
        @Suppress("UNUSED_PARAMETER") pendingExecutionErrorRecoveredSessions: Set<String>
    ) {
        conversationList.value = conversations
            .withPendingExecutionErrorExitStatuses(pendingExecutionErrorExitSessions)
        conversationError.value = null
    }

    fun applyLoadFailure(message: String?) {
        conversationError.value = message ?: "Conversation list load failed"
    }

    fun finishLoad() {
        conversationLoading.value = false
    }
}
