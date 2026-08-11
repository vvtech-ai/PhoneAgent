package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem

private const val ExecutionErrorStatus = "EXECUTION_ERROR"

internal fun taskStatusAfterConfirmedErrorRecovery(taskStatus: String): String {
    return taskStatus
}

internal fun List<ConversationListItem>.withPendingExecutionErrorExitStatuses(
    pendingSessionIds: Set<String>
): List<ConversationListItem> {
    val pending = pendingSessionIds.normalizedSessionIds()
    if (pending.isEmpty()) return this
    return map { item ->
        if (item.sessionId in pending) item.copy(status = ExecutionErrorStatus) else item
    }
}

internal fun List<ConversationListItem>.withRecoveredExecutionErrorStatuses(
    @Suppress("UNUSED_PARAMETER") recoveredSessionIds: Set<String>
): List<ConversationListItem> {
    return this
}

private fun Set<String>.normalizedSessionIds(): Set<String> {
    return map { it.trim() }
        .filter { it.isNotBlank() }
        .toSet()
}
