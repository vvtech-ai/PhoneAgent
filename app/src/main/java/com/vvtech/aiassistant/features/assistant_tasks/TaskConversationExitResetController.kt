package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.shouldPersistExecutionErrorOnTaskExit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class TaskConversationExitResetDeps(
    val scope: CoroutineScope,
    val stateReader: TaskConversationExitResetStateReader,
    val taskRestoreStateHolder: TaskRestoreStateHolder
)

internal data class TaskConversationExitResetCallbacks(
    val stopVoiceInteraction: (String) -> Unit,
    val resetToIdleHome: () -> Unit,
    val agentSessionId: () -> String?,
    val updateCurrentConversationCardBeforeExit: (String?, Index9AssistantUiState) -> Unit,
    val rememberPendingExecutionErrorExit: (String) -> Unit,
    val syncPendingExecutionErrorExitSessions: suspend () -> Boolean
)

internal class TaskConversationExitResetController(
    private val deps: TaskConversationExitResetDeps,
    private val callbacks: TaskConversationExitResetCallbacks,
    private val loadConversations: (String) -> Unit
) {
    fun pauseAndResetLocalUi(
        reason: String = "navigate_back_pause",
        reloadConversations: Boolean = true
    ) {
        val stateBeforeExit = deps.stateReader.currentState()
        val sessionId = callbacks.agentSessionId()
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?: stateBeforeExit.taskId?.trim()?.takeIf { it.isNotBlank() }
        callbacks.updateCurrentConversationCardBeforeExit(
            sessionId,
            stateBeforeExit
        )
        val persistExecutionError = shouldPersistExecutionErrorOnTaskExit(
            taskStatus = stateBeforeExit.taskStatus,
            unresolvedTaskErrorStatus = stateBeforeExit.unresolvedTaskErrorStatus,
            taskErrorRecoveryInProgress = stateBeforeExit.taskErrorRecoveryInProgress
        )
        callbacks.stopVoiceInteraction(reason)
        if (persistExecutionError && !sessionId.isNullOrBlank()) {
            callbacks.rememberPendingExecutionErrorExit(sessionId)
            deps.taskRestoreStateHolder.updateConversationCardStatus(
                sessionId = sessionId,
                status = "EXECUTION_ERROR"
            )
            deps.scope.launch {
                callbacks.syncPendingExecutionErrorExitSessions()
            }
        }
        callbacks.resetToIdleHome()
        if (reloadConversations) {
            loadConversations("vm_pause:$reason")
        }
    }
}
