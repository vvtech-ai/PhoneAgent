package com.vvtech.aiassistant.features.assistant_tasks

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class TaskErrorRecoveryNetworkRetryController(
    private val networkRegistrar: TaskErrorRecoveryNetworkCallbackRegistrar,
    private val scope: CoroutineScope,
    private val pendingExecutionErrorExitSessions: () -> Set<String>,
    private val pendingExecutionErrorRecoveredSessions: () -> Set<String>,
    private val syncPendingExecutionErrorExitSessions: suspend () -> Boolean,
    private val syncPendingExecutionErrorRecoveredSessions: suspend () -> Boolean,
    private val hasActiveAiCallContext: () -> Boolean,
    private val restartCallSessionPolling: () -> Unit,
    private val loadConversations: () -> Unit,
    private val log: (String) -> Unit
) {
    fun register() {
        networkRegistrar.register(::onNetworkAvailable)
    }

    fun unregister() {
        networkRegistrar.unregister()
    }

    private fun onNetworkAvailable() {
        val hasPendingExecutionError = pendingExecutionErrorExitSessions().isNotEmpty() ||
            pendingExecutionErrorRecoveredSessions().isNotEmpty()
        val hasActiveCall = hasActiveAiCallContext()
        if (!hasPendingExecutionError && !hasActiveCall) {
            return
        }
        scope.launch {
            if (hasActiveCall) {
                log("network available, restart active call session polling")
                restartCallSessionPolling()
            }
            if (hasPendingExecutionError) {
                log("network available, retry pending execution error status sync")
                syncPendingExecutionErrorExitSessions()
                syncPendingExecutionErrorRecoveredSessions()
                loadConversations()
            }
        }
    }
}
