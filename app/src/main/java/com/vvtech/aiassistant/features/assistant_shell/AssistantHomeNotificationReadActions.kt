package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalHomeNotificationItem
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal object AssistantHomeNotificationReadActions {
    fun markPendingRead(
        readState: AssistantHomeNotificationReadState,
        pendingNotifications: List<FinalHomeNotificationItem>
    ): Boolean {
        return readState.markRead(pendingNotifications.map { it.id })
    }

    fun dismissCurrent(
        readState: AssistantHomeNotificationReadState,
        currentNotification: FinalHomeNotificationItem?
    ): Boolean {
        return currentNotification?.let { readState.markRead(listOf(it.id)) } ?: false
    }

    fun dismissTaskForUserClose(
        readState: AssistantHomeNotificationReadState,
        sessionId: String?,
        taskId: String?
    ): Boolean {
        val normalizedSessionId = sessionId?.trim()?.takeIf(String::isNotEmpty)
        val normalizedTaskId = taskId?.trim()?.takeIf(String::isNotEmpty)
        val notificationIds = buildList {
            normalizedSessionId?.let { add("conversation_$it") }
            normalizedTaskId?.let {
                add("assistant_task_$it")
                add("legacy_task_$it")
            }
        }
        val changed = readState.markRead(notificationIds)
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.TASK,
                eventType = "HOME_NOTIFICATION_DISMISSED_FOR_TASK_CLOSE",
                sessionId = normalizedSessionId,
                taskId = normalizedTaskId,
                result = when {
                    notificationIds.isEmpty() -> "skipped"
                    changed -> "dismissed"
                    else -> "already_dismissed"
                },
                reason = if (notificationIds.isEmpty()) "missing_identity" else "user_closed_task",
                attributes = mapOf("notificationIds" to notificationIds.joinToString(",")),
            )
        )
        return changed
    }
}
