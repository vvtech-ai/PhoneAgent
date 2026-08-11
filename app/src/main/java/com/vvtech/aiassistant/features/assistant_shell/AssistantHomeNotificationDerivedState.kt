package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.FinalHomeNotificationItem
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.features.assistant.FinalTaskStatusKind
import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.buildHomeNotificationItems
import com.vvtech.aiassistant.features.assistant.isCompletedConversationStatus
import com.vvtech.aiassistant.features.assistant.pendingHomeNotificationItems
import com.vvtech.aiassistant.features.assistant.taskBadgeCountFromPendingNotifications
import com.vvtech.aiassistant.model.ConversationListItem

internal class AssistantHomeNotificationDerivedStateInput(
    val currentPage: FinalPage,
    val localCallRecords: List<FinalCallRecord>,
    val backendHistoryRecords: List<HistoryRecord>,
    val taskRecords: List<FinalTaskRecord>,
    val conversations: List<ConversationListItem>,
    val dismissedHomeNotificationIds: List<String>
)

internal class AssistantHomeNotificationDerivedState(
    val visibleCallRecords: List<FinalCallRecord>,
    val visibleTaskRecords: List<FinalTaskRecord>,
    val completedConversations: List<ConversationListItem>,
    val homeNotificationItems: List<FinalHomeNotificationItem>,
    val pendingHomeNotifications: List<FinalHomeNotificationItem>,
    val taskBadgeCount: Int,
    val currentHomeNotification: FinalHomeNotificationItem?,
    val homeNotificationVisible: Boolean,
    val homeNotificationText: String,
    val homeNotificationExtra: String,
    val homeNotificationStatusKind: FinalTaskStatusKind
)

internal fun deriveAssistantHomeNotificationState(
    input: AssistantHomeNotificationDerivedStateInput
): AssistantHomeNotificationDerivedState {
    val backendCallRecords = input.backendHistoryRecords.map { history ->
        FinalCallRecord(
            title = history.title,
            status = history.status,
            meta = history.meta,
            success = history.style == StatusStyle.Success,
            occurredAtMillis = history.occurredAtMillis,
            phoneNumber = history.phoneNumber,
            dateText = history.dateText,
            startTimeText = history.startTimeText,
            endTimeText = history.endTimeText,
            durationText = history.durationText,
            resultText = history.resultText,
            transcript = history.transcript,
            taskId = history.taskId,
            callId = history.callId
        )
    }
    val visibleCallRecords = (input.localCallRecords + backendCallRecords)
        .distinctBy {
            listOf(
                it.title,
                it.status,
                it.meta,
                it.taskId,
                it.callId,
                it.phoneNumber,
                it.startTimeText,
                it.endTimeText,
                it.resultText
            ).joinToString("\u0000")
        }
        .sortedByDescending { it.occurredAtMillis ?: Long.MIN_VALUE }
    val visibleTaskRecords = input.taskRecords.toList()
    val completedConversations = input.conversations.filter {
        isCompletedConversationStatus(it.status)
    }
    val homeNotificationItems = buildHomeNotificationItems(
        completedTaskRecords = visibleTaskRecords,
        completedConversations = completedConversations
    )
    val pendingHomeNotifications = pendingHomeNotificationItems(
        items = homeNotificationItems,
        dismissedIds = input.dismissedHomeNotificationIds
    )
    val currentHomeNotification = pendingHomeNotifications.firstOrNull()

    return AssistantHomeNotificationDerivedState(
        visibleCallRecords = visibleCallRecords,
        visibleTaskRecords = visibleTaskRecords,
        completedConversations = completedConversations,
        homeNotificationItems = homeNotificationItems,
        pendingHomeNotifications = pendingHomeNotifications,
        taskBadgeCount = taskBadgeCountFromPendingNotifications(pendingHomeNotifications),
        currentHomeNotification = currentHomeNotification,
        homeNotificationVisible = input.currentPage == FinalPage.Home && currentHomeNotification != null,
        homeNotificationText = currentHomeNotification?.text.orEmpty(),
        homeNotificationExtra = if (pendingHomeNotifications.size > 1) {
            "还有 ${pendingHomeNotifications.size - 1} 条"
        } else {
            ""
        },
        homeNotificationStatusKind = currentHomeNotification?.statusKind ?: FinalTaskStatusKind.Completed
    )
}
