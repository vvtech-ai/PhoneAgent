package com.vvtech.aiassistant.features.assistant_tasks

import android.content.Context
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

internal class TaskErrorRecoveryPendingController(
    private val pendingStore: TaskErrorRecoveryPendingStore,
    private val pendingStatusHolder: TaskErrorRecoveryPendingStatusHolder,
    private val pendingSyncUseCase: TaskErrorRecoveryPendingSyncUseCase
) {
    private val syncMutex = Mutex()

    fun pendingExecutionErrorExitSessions(): MutableSet<String> {
        return pendingStore.pendingExecutionErrorExitSessions()
    }

    fun rememberPendingExecutionErrorExit(sessionId: String) {
        pendingStore.rememberPendingExecutionErrorExit(sessionId)
        pendingStatusHolder.applyPendingExecutionErrorExitStatuses(
            pendingExecutionErrorExitSessions()
        )
    }

    fun pendingExecutionErrorRecoveredSessions(): MutableSet<String> {
        return pendingStore.pendingExecutionErrorRecoveredSessions()
    }

    fun rememberPendingExecutionErrorRecovered(sessionId: String) {
        pendingStore.rememberPendingExecutionErrorRecovered(sessionId)
    }

    suspend fun syncPendingExecutionErrorExitSessions(): Boolean = syncMutex.withLock {
        val result = pendingSyncUseCase.syncPendingExecutionErrorExitSessions(
            pendingSessions = pendingExecutionErrorExitSessions(),
            conversations = pendingStatusHolder.currentConversations(),
            onSynced = pendingStore::forgetPendingExecutionErrorExit
        )
        pendingStatusHolder.applySyncedConversations(result)
        result.syncedAny
    }

    suspend fun syncPendingExecutionErrorRecoveredSessions(): Boolean = syncMutex.withLock {
        val result = pendingSyncUseCase.syncPendingExecutionErrorRecoveredSessions(
            pendingSessions = pendingExecutionErrorRecoveredSessions(),
            conversations = pendingStatusHolder.currentConversations(),
            onSynced = pendingStore::forgetPendingExecutionErrorRecovered
        )
        pendingStatusHolder.applySyncedConversations(result)
        result.syncedAny
    }
}

internal object TaskErrorRecoveryPendingControllerFactory {
    fun create(
        appContext: Context,
        repository: AssistantRepository,
        conversationList: MutableStateFlow<List<ConversationListItem>>,
        log: (String) -> Unit
    ): TaskErrorRecoveryPendingController {
        return TaskErrorRecoveryPendingController(
            pendingStore = TaskErrorRecoveryPendingStore(appContext),
            pendingStatusHolder = TaskErrorRecoveryPendingStatusHolder(conversationList),
            pendingSyncUseCase = TaskErrorRecoveryPendingSyncUseCase(
                repository = repository,
                log = log
            )
        )
    }
}
