package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.SharedPreferences
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.AssistantHistoryItem
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant_tasks.normalizeTaskDisplayTimeText
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayAppointmentTimeLabel
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayRecordSortInstant
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayRelativeTimeLabel
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplaySortEpochMillis
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayStartTimeLabel
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.ConversationDetail
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.model.ReservationSlot
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private const val REPORT_CALL_OUTCOME_TAG = "ReportCallOutcome"

internal fun normalizeDialNumber(value: String): String = value.filter { it.isDigit() || it == '*' || it == '#' }

internal fun formatDialNumber(value: String): String {
    val raw = normalizeDialNumber(value)
    if (raw.isBlank()) return ""
    return raw.chunked(3).joinToString(" ")
}

internal fun formatSeconds(seconds: Int): String = "%02d:%02d".format(seconds / 60, seconds % 60)

internal data class FinalTaskDisplayItem(
    val id: String,
    val sceneName: String,
    val sceneTarget: String,
    val keyInfo: String,
    val timeLabel: String,
    val startTimeLabel: String,
    val appointmentTimeLabel: String,
    val sortInstant: Instant?,
    val statusKind: FinalTaskStatusKind,
    val statusLabel: String = statusKind.label
) {
    val displayTitle: String
        get() {
            val localizedSceneName = localizedFinalTaskText(sceneName)
            val localizedSceneTarget = localizedFinalTaskText(sceneTarget)
            return if (sceneTarget.isBlank()) localizedSceneName else "$localizedSceneName · $localizedSceneTarget"
        }
    val secondaryLine: String
        get() = localizedFinalTaskText(finalTaskSecondaryLine(startTimeLabel, appointmentTimeLabel, keyInfo))
}

internal fun isFinalTaskPageLoading(
    realTaskLoading: Boolean,
    conversationLoading: Boolean
): Boolean = realTaskLoading || conversationLoading

internal fun shouldShowFinalTaskEmptyState(
    recordsEmpty: Boolean,
    completedConversationsEmpty: Boolean,
    activeConversationsEmpty: Boolean,
    activeConversationTitle: String?,
    loading: Boolean
): Boolean {
    return recordsEmpty &&
        completedConversationsEmpty &&
        activeConversationsEmpty &&
        activeConversationTitle == null &&
        !loading
}

internal fun shouldShowActiveConversationShortcut(
    sessionId: String?,
    taskStatus: String
): Boolean {
    if (sessionId.isNullOrBlank()) return false
    return canonicalConversationTaskStatus(taskStatus) == "RUNNING"
}

private const val FinalTaskSecondarySeparator = " \u00B7 "

private fun finalTaskSecondaryLine(
    startTimeLabel: String,
    appointmentTimeLabel: String,
    keyInfo: String
): String {
    val timeParts = listOf(startTimeLabel, appointmentTimeLabel)
        .flatMap(::splitFinalTaskSecondaryParts)
    val keyParts = splitFinalTaskSecondaryParts(keyInfo)
        .map { removeFinalTaskTimeExpressions(it) }
    return (timeParts + keyParts)
        .filter { it.isNotBlank() }
        .distinct()
        .joinToString(FinalTaskSecondarySeparator)
}

private fun splitFinalTaskSecondaryParts(value: String): List<String> {
    return value
        .split(FinalTaskSecondarySeparator, " \u8def ", " \u74ba? ", "\u8def", "\u74ba?")
        .map { it.trim() }
}

internal fun finalCallTimeLabel(
    meta: String,
    index: Int,
    occurredAtMillis: Long? = null,
    nowMillis: Long = System.currentTimeMillis(),
    zoneId: ZoneId = ZoneId.systemDefault()
): String {
    occurredAtMillis?.let { timestamp ->
        val occurredAt = Instant.ofEpochMilli(timestamp).atZone(zoneId)
        val now = Instant.ofEpochMilli(nowMillis).atZone(zoneId)
        val deltaMillis = nowMillis - timestamp
        if (deltaMillis in 0 until 60_000) {
            return currentAppText("刚刚", "Just now")
        }
        if (occurredAt.toLocalDate() == now.toLocalDate()) {
            return occurredAt.format(DateTimeFormatter.ofPattern("HH:mm"))
        }
        if (occurredAt.toLocalDate() == now.toLocalDate().minusDays(1)) {
            return currentAppText("昨天", "Yesterday")
        }
        return occurredAt.format(
            if (occurredAt.year == now.year) {
                DateTimeFormatter.ofPattern(currentAppText("M月d日", "MMM d"), Locale.US)
            }
            else DateTimeFormatter.ofPattern("yyyy/M/d")
        )
    }
    val tokens = meta
        .replace("·", " ")
        .replace("路", " ")
        .split(" ")
        .map { it.trim() }
        .filter { it.isNotBlank() }
    val timeToken = tokens.firstOrNull { it.contains(":") }
    if (!timeToken.isNullOrBlank()) return timeToken
    return if (index == 0) currentAppText("刚刚", "Just now") else currentAppText("昨天", "Yesterday")
}

internal fun FinalTaskRecord.toFinalTaskDisplayItem(index: Int = 0): FinalTaskDisplayItem {
    val combinedText = finalTaskCombinedText(title, detail, sourceText)
    val sceneName = finalTaskSceneName(sceneType, combinedText)
    val sortInstant = finalTaskRecordSortInstant(this)
    val startLabel = finalTaskStartTimeLabel(startedAt, combinedText)
    val appointmentLabel = finalTaskAppointmentTimeLabel(scheduledAt, combinedText, startLabel)
    return FinalTaskDisplayItem(
        id = notificationId ?: "task_${index}_${(title + detail + sourceText).hashCode()}",
        sceneName = sceneName,
        sceneTarget = finalTaskSceneTarget(sceneName, title, detail, sourceText),
        keyInfo = finalTaskKeyInfo(sceneName, title, detail, sourceText),
        timeLabel = startLabel,
        startTimeLabel = startLabel,
        appointmentTimeLabel = appointmentLabel,
        sortInstant = sortInstant,
        statusKind = finalTaskStatusKind(status),
        statusLabel = finalTaskStatusDisplayLabel(status)
    )
}

internal fun ConversationListItem.toFinalTaskDisplayItem(index: Int = 0): FinalTaskDisplayItem {
    val timestamp = updatedAt?.trim()?.takeIf { it.isNotBlank() }
        ?: createdAt?.trim()?.takeIf { it.isNotBlank() }
        ?: currentAppText("点击继续对话", "Tap to continue")
    val safeTitle = title.orEmpty()
    return FinalTaskRecord(
        title = safeTitle.ifBlank { assistantSceneTitle(sceneType.orEmpty(), sessionId) },
        status = conversationStatusLabel(status),
        detail = timestamp,
        sceneType = sceneType,
        sourceText = safeTitle,
        notificationId = "conversation_$sessionId",
        startedAt = timestamp
    ).toFinalTaskDisplayItem(index)
}

internal fun finalTaskRecordSortEpochMillis(record: FinalTaskRecord): Long =
    taskDisplaySortEpochMillis(finalTaskRecordSortInstant(record))

internal fun finalTaskDisplaySortEpochMillis(item: FinalTaskDisplayItem): Long =
    taskDisplaySortEpochMillis(item.sortInstant)

internal fun finalTaskRecordSortInstant(record: FinalTaskRecord): Instant? =
    taskDisplayRecordSortInstant(
        startedAt = record.startedAt,
        detail = record.detail,
        sourceText = record.sourceText,
        title = record.title,
        scheduledAt = record.scheduledAt
    )

internal fun finalTaskRelativeTimeLabel(
    raw: String?,
    today: LocalDate = LocalDate.now(),
    zoneId: ZoneId = ZoneId.systemDefault()
): String = taskDisplayRelativeTimeLabel(raw, today, zoneId)

private fun finalTaskStartTimeLabel(startedAt: String, combinedText: String): String =
    taskDisplayStartTimeLabel(startedAt, combinedText)

private fun finalTaskAppointmentTimeLabel(
    scheduledAt: String,
    combinedText: String,
    startTimeLabel: String
): String = taskDisplayAppointmentTimeLabel(scheduledAt, combinedText, startTimeLabel)

internal fun normalizeFinalTaskTimeText(value: String): String =
    normalizeTaskDisplayTimeText(value)

internal fun AssistantHistoryItem.toFinalTaskRecord(): FinalTaskRecord {
    val titleText = title?.trim()
        ?.takeIf { it.isNotBlank() }
        ?: assistantSceneTitle(sceneType, taskId)
    val detailParts = listOfNotNull(
        resultHeadline?.trim()?.takeIf { it.isNotBlank() },
        resultDetail?.trim()?.takeIf { it.isNotBlank() },
        subtitle?.trim()?.takeIf { it.isNotBlank() },
        updatedAt?.trim()?.takeIf { it.isNotBlank() }
    ).distinct()
    val detailText = detailParts.joinToString(" · ").ifBlank {
        currentAppText("任务已同步，等待进一步处理", "Task synced, waiting for next steps")
    }
    return FinalTaskRecord(
        title = titleText,
        status = backendTaskStatusLabel(resultStatus?.takeIf { it.isNotBlank() } ?: taskStatus),
        detail = detailText,
        sceneType = sceneType,
        sourceText = subtitle.orEmpty(),
        notificationId = "assistant_task_$taskId",
        startedAt = updatedAt.orEmpty()
    )
}

internal fun assistantSceneTitle(sceneType: String, taskId: String): String = when (sceneType.uppercase(Locale.ROOT)) {
    "RESTAURANT_BOOKING" -> currentAppText("订餐任务", "Restaurant Booking")
    "HOTEL_BOOKING" -> currentAppText("订酒店任务", "Hotel Booking")
    "FLIGHT_BOOKING" -> currentAppText("订机票任务", "Flight Booking")
    "AI_CALL" -> currentAppText("AI 通话任务", "AI Call")
    else -> currentAppText("AI 任务 ${taskId.takeLast(6)}", "AI Task ${taskId.takeLast(6)}")
}

internal fun TaskListItem.toFinalTaskRecord(): FinalTaskRecord {
    val titleText = originText.ifBlank { currentAppText("AI 任务 ${taskId.takeLast(6)}", "AI Task ${taskId.takeLast(6)}") }
    val detailText = listOfNotNull(
        slot?.toFinalTaskSlotSummary()?.takeIf { it.isNotBlank() },
        finalResult?.takeIf { it.isNotBlank() },
        callResultText?.takeIf { it.isNotBlank() },
        createdAt.takeIf { it.isNotBlank() }
    ).joinToString(" · ").ifBlank {
        currentAppText("任务已提交，等待进一步处理", "Task submitted, waiting for next steps")
    }
    return FinalTaskRecord(
        title = titleText,
        status = backendTaskStatusLabel(status),
        detail = detailText,
        sourceText = originText,
        notificationId = "legacy_task_$taskId",
        startedAt = createdAt
    )
}

private fun ReservationSlot.toFinalTaskSlotSummary(): String {
    return listOfNotNull(
        reservationTime?.trim()?.takeIf { it.isNotBlank() },
        partySize?.takeIf { it > 0 }?.let { currentAppText("${it}位", "$it people") },
        restaurantName?.trim()?.takeIf { it.isNotBlank() },
        locationIntent?.trim()?.takeIf { it.isNotBlank() },
        cuisine?.trim()?.takeIf { it.isNotBlank() }
    )
        .distinct()
        .joinToString(" · ")
}

internal data class FinalHomeNotificationItem(
    val id: String,
    val text: String,
    val sourceSessionId: String? = null,
    val statusKind: FinalTaskStatusKind = FinalTaskStatusKind.Completed
)

internal fun buildHomeNotificationItems(
    completedTaskRecords: List<FinalTaskRecord>,
    completedConversations: List<ConversationListItem>
): List<FinalHomeNotificationItem> {
    val realItems = buildList {
        completedConversations.forEachIndexed { index, conversation ->
            val record = conversation.toCompletedTaskRecord()
            val displayItem = record.toFinalTaskDisplayItem(index)
            add(
                QueuedHomeNotificationItem(
                    item = FinalHomeNotificationItem(
                        id = "conversation_${conversation.sessionId}",
                        text = homeNotificationText(displayItem),
                        sourceSessionId = conversation.sessionId,
                        statusKind = displayItem.statusKind
                    ),
                    sortInstant = extractFinalTaskInstant(
                        conversation.updatedAt ?: conversation.createdAt ?: record.detail
                    ),
                    originalIndex = index
                )
            )
        }
        completedTaskRecords.forEachIndexed { index, record ->
            val displayItem = record.toFinalTaskDisplayItem(index)
            add(
                QueuedHomeNotificationItem(
                    item = FinalHomeNotificationItem(
                        id = record.notificationId ?: "task_${record.title.hashCode()}_${record.detail.hashCode()}",
                        text = homeNotificationText(displayItem),
                        statusKind = displayItem.statusKind
                    ),
                    sortInstant = finalTaskRecordSortInstant(record),
                    originalIndex = completedConversations.size + index
                )
            )
        }
    }
    val sortedRealItems = realItems
        .sortedWith(
            compareByDescending<QueuedHomeNotificationItem> { it.sortInstant ?: Instant.EPOCH }
                .thenBy { it.originalIndex }
        )
        .map { it.item }
        .distinctBy { "${it.text}\u0000${it.sourceSessionId.orEmpty()}" }
    return sortedRealItems
}

internal fun pendingHomeNotificationItems(
    items: List<FinalHomeNotificationItem>,
    dismissedIds: List<String>
): List<FinalHomeNotificationItem> {
    if (dismissedIds.isEmpty()) return items
    val dismissed = dismissedIds.toSet()
    return items.filterNot { dismissed.contains(it.id) }
}

internal fun taskBadgeCountFromPendingNotifications(
    pendingNotifications: List<FinalHomeNotificationItem>
): Int {
    return pendingNotifications.size
}

internal fun localizedFinalTaskText(raw: String): String {
    var text = raw
    mapOf(
        "订餐厅" to "Restaurant Booking",
        "订餐任务" to "Restaurant Booking",
        "订酒店任务" to "Hotel Booking",
        "订酒店" to "Hotel Booking",
        "酒店任务" to "Hotel Booking",
        "订机票任务" to "Flight Booking",
        "订机票" to "Flight Booking",
        "会议通知" to "Meeting Notification",
        "会议邀请" to "Meeting Invitation",
        "AI 通话任务" to "AI Call",
        "AI 通话" to "AI Call",
        "AI通话" to "AI Call",
        "目标对象" to "Target",
        "参会人" to "Attendees",
        "酒店" to "Hotel",
        "航班" to "Flight",
        "任务已同步，等待进一步处理" to "Task synced, waiting for next steps",
        "任务已提交，等待进一步处理" to "Task submitted, waiting for next steps",
        "点击继续对话" to "Tap to continue",
        "刚刚" to "Just now",
        "昨天" to "Yesterday"
    ).forEach { (chinese, english) ->
        text = text.replace(chinese, currentAppText(chinese, english))
    }
    text = text
        .replace(Regex("""(\d+)\s*位""")) { match ->
            currentAppText(match.value, "${match.groupValues[1]} people")
        }
        .replace("：", currentAppText("：", ": "))
    return text
}
