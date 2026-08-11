package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class TaskConversationListLoadControllerDeps(
    val scope: CoroutineScope,
    val stateHolder: TaskConversationListLoadStateHolder,
    val accountIdProvider: () -> String,
    val load: suspend (String, Set<String>, Set<String>) -> List<ConversationListItem>
)

internal data class TaskConversationListLoadControllerCallbacks(
    val pendingExecutionErrorExitSessions: () -> Set<String>,
    val pendingExecutionErrorRecoveredSessions: () -> Set<String>,
    val syncPendingExecutionErrorExitSessions: suspend () -> Boolean,
    val syncPendingExecutionErrorRecoveredSessions: suspend () -> Boolean
)

internal class TaskConversationListLoadController(
    private val deps: TaskConversationListLoadControllerDeps,
    private val callbacks: TaskConversationListLoadControllerCallbacks,
    private val warn: (String) -> Unit = { message -> AppFileLogger.w("Index9VM", message) }
) {
    private val stateHolder = deps.stateHolder

    @Suppress("UNUSED_PARAMETER")
    fun loadConversations(reason: String = "default") {
        if (stateHolder.isLoading()) return
        stateHolder.beginLoad()
        deps.scope.launch {
            runCatching {
                callbacks.syncPendingExecutionErrorExitSessions()
                callbacks.syncPendingExecutionErrorRecoveredSessions()
                val pendingError = callbacks.pendingExecutionErrorExitSessions()
                val pendingRecovered = callbacks.pendingExecutionErrorRecoveredSessions()
                deps.load(
                    deps.accountIdProvider(),
                    pendingError,
                    pendingRecovered
                )
            }.onSuccess { list ->
                stateHolder.applyLoadedConversations(
                    conversations = list,
                    pendingExecutionErrorExitSessions = callbacks.pendingExecutionErrorExitSessions(),
                    pendingExecutionErrorRecoveredSessions = callbacks.pendingExecutionErrorRecoveredSessions()
                )
            }.onFailure { throwable ->
                warn("loadConversations failed: ${throwable.message}")
                stateHolder.applyLoadFailure(throwable.message)
            }.also {
                stateHolder.finishLoad()
            }
        }
    }
}
