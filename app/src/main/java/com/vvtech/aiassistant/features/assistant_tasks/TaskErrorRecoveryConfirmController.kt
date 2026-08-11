package com.vvtech.aiassistant.features.assistant_tasks

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class TaskErrorRecoveryConfirmController(
    private val uiStateHolder: TaskErrorRecoveryUiStateHolder,
    private val scope: CoroutineScope,
    private val currentAgentSessionId: () -> String?,
    private val rememberPendingExecutionErrorRecovered: (String) -> Unit,
    private val syncPendingExecutionErrorRecoveredSessions: suspend () -> Boolean,
    private val log: (String) -> Unit
) {
    fun confirm(reason: String, promoteToRunning: Boolean) {
        val state = uiStateHolder.currentState()
        val confirmedPlan = uiStateHolder.confirmedRecoveryPlan(promoteToRunning)
        if (!confirmedPlan.shouldApply) return
        val sessionId = currentAgentSessionId()
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?: state.taskId?.trim()?.takeIf { it.isNotBlank() }
        uiStateHolder.applyConfirmedRecovery(confirmedPlan)
        if (promoteToRunning && confirmedPlan.recoverableStatus && !sessionId.isNullOrBlank()) {
            rememberPendingExecutionErrorRecovered(sessionId)
            scope.launch {
                syncPendingExecutionErrorRecoveredSessions()
            }
        }
        log("markTaskErrorRecoveryConfirmed reason=$reason")
    }
}
