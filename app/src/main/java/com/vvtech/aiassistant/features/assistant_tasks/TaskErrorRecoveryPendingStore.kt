package com.vvtech.aiassistant.features.assistant_tasks

import android.content.Context

private const val PendingExecutionErrorExitSessionsKey = "pending_execution_error_exit_sessions"
private const val PendingExecutionErrorRecoveredSessionsKey =
    "pending_execution_error_recovered_sessions"

internal class TaskErrorRecoveryPendingStore(
    appContext: Context
) {
    private val prefs =
        appContext.getSharedPreferences("index9_task_error_exit", Context.MODE_PRIVATE)

    fun pendingExecutionErrorExitSessions(): MutableSet<String> {
        return pendingSessions(PendingExecutionErrorExitSessionsKey)
    }

    fun rememberPendingExecutionErrorExit(sessionId: String) {
        val normalized = normalizedSessionId(sessionId) ?: return
        forgetPendingExecutionErrorRecovered(normalized)
        val pending = pendingExecutionErrorExitSessions().apply { add(normalized) }
        savePendingSessions(PendingExecutionErrorExitSessionsKey, pending)
    }

    fun forgetPendingExecutionErrorExit(sessionId: String) {
        val normalized = normalizedSessionId(sessionId) ?: return
        val pending = pendingExecutionErrorExitSessions().apply { remove(normalized) }
        savePendingSessions(PendingExecutionErrorExitSessionsKey, pending)
    }

    fun pendingExecutionErrorRecoveredSessions(): MutableSet<String> {
        return pendingSessions(PendingExecutionErrorRecoveredSessionsKey)
    }

    fun rememberPendingExecutionErrorRecovered(sessionId: String) {
        val normalized = normalizedSessionId(sessionId) ?: return
        forgetPendingExecutionErrorExit(normalized)
        val pending = pendingExecutionErrorRecoveredSessions().apply { add(normalized) }
        savePendingSessions(PendingExecutionErrorRecoveredSessionsKey, pending)
    }

    fun forgetPendingExecutionErrorRecovered(sessionId: String) {
        val normalized = normalizedSessionId(sessionId) ?: return
        val pending = pendingExecutionErrorRecoveredSessions().apply { remove(normalized) }
        savePendingSessions(PendingExecutionErrorRecoveredSessionsKey, pending)
    }

    private fun pendingSessions(key: String): MutableSet<String> {
        return prefs
            .getStringSet(key, emptySet())
            .orEmpty()
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .toMutableSet()
    }

    private fun savePendingSessions(key: String, sessions: Set<String>) {
        prefs.edit().putStringSet(key, sessions).apply()
    }

    private fun normalizedSessionId(sessionId: String): String? {
        return sessionId.trim().takeIf { it.isNotBlank() }
    }
}
