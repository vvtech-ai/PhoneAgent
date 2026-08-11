package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.core.model.AgentConversationInterruptResponse
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.model.ConversationListItem

private const val ExecutionErrorExitReason = "execution_error_exit"
private const val ExecutionErrorRecoveredReason = "execution_error_recovered"

internal data class TaskErrorRecoveryPendingSyncResult(
    val syncedAny: Boolean,
    val conversations: List<ConversationListItem>
)

internal class TaskErrorRecoveryPendingSyncUseCase(
    private val interruptConversation: suspend (
        sessionId: String,
        userId: String,
        reason: String?
    ) -> AgentConversationInterruptResponse,
    private val log: (String) -> Unit,
    private val accountId: () -> String = { AccountIdentityProvider.accountId },
    private val warn: (String) -> Unit = { message -> AppFileLogger.w("Index9VM", message) }
) {
    constructor(
        repository: AssistantRepository,
        log: (String) -> Unit,
        accountId: () -> String = { AccountIdentityProvider.accountId },
        warn: (String) -> Unit = { message -> AppFileLogger.w("Index9VM", message) }
    ) : this(
        interruptConversation = repository::interruptConversation,
        log = log,
        accountId = accountId,
        warn = warn
    )

    suspend fun syncPendingExecutionErrorExitSessions(
        pendingSessions: Set<String>,
        conversations: List<ConversationListItem>,
        onSynced: (String) -> Unit
    ): TaskErrorRecoveryPendingSyncResult {
        return syncPendingSessions(
            pendingSessions = pendingSessions,
            conversations = conversations,
            reason = ExecutionErrorExitReason,
            logLabel = "exit",
            onSynced = onSynced
        )
    }

    suspend fun syncPendingExecutionErrorRecoveredSessions(
        pendingSessions: Set<String>,
        conversations: List<ConversationListItem>,
        onSynced: (String) -> Unit
    ): TaskErrorRecoveryPendingSyncResult {
        return syncPendingSessions(
            pendingSessions = pendingSessions,
            conversations = conversations,
            reason = ExecutionErrorRecoveredReason,
            logLabel = "recovery",
            onSynced = onSynced
        )
    }

    private suspend fun syncPendingSessions(
        pendingSessions: Set<String>,
        conversations: List<ConversationListItem>,
        reason: String,
        logLabel: String,
        onSynced: (String) -> Unit
    ): TaskErrorRecoveryPendingSyncResult {
        val normalizedPending = pendingSessions
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
        if (normalizedPending.isEmpty()) {
            return TaskErrorRecoveryPendingSyncResult(
                syncedAny = false,
                conversations = conversations
            )
        }

        var syncedAny = false
        var updatedConversations = conversations
        normalizedPending.forEach { sessionId ->
            runCatching {
                interruptConversation(sessionId, accountId(), reason)
            }.onSuccess { response ->
                syncedAny = true
                onSynced(sessionId)
                updatedConversations = TaskConversationListStatusReducer.updateStatus(
                    conversations = updatedConversations,
                    sessionId = sessionId,
                    status = response.status
                )
                log("synced pending execution error $logLabel session=$sessionId status=${response.status}")
            }.onFailure { throwable ->
                warn("sync pending execution error $logLabel failed session=$sessionId: ${throwable.message}")
            }
        }
        return TaskErrorRecoveryPendingSyncResult(
            syncedAny = syncedAny,
            conversations = updatedConversations
        )
    }
}
