package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.model.ConversationListItem

internal class TaskConversationListLoadUseCase(
    private val repository: AssistantRepository
) {
    suspend fun load(
        accountId: String,
        pendingExecutionErrorExitSessions: Set<String>,
        @Suppress("UNUSED_PARAMETER") pendingExecutionErrorRecoveredSessions: Set<String>
    ): List<ConversationListItem> {
        return repository.getConversations(accountId)
            .withPendingExecutionErrorExitStatuses(pendingExecutionErrorExitSessions)
    }
}
