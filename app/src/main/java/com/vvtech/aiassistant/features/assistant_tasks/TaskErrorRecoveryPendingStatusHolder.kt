package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class TaskErrorRecoveryPendingStatusHolder(
    private val conversationList: MutableStateFlow<List<ConversationListItem>>
) {
    fun currentConversations(): List<ConversationListItem> {
        return conversationList.value
    }

    fun applyPendingExecutionErrorExitStatuses(pendingSessions: Set<String>) {
        conversationList.update {
            it.withPendingExecutionErrorExitStatuses(pendingSessions)
        }
    }

    fun applySyncedConversations(result: TaskErrorRecoveryPendingSyncResult) {
        if (result.syncedAny) {
            conversationList.value = result.conversations
        }
    }
}
