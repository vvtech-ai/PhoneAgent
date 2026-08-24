package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_tasks.TASK_DISPLAY_CHINESE_CLOCK_TIME_CLEANUP_REGEX
import com.vvtech.aiassistant.features.assistant_tasks.TASK_DISPLAY_CLOCK_TIME_CLEANUP_REGEX
import com.vvtech.aiassistant.features.assistant_tasks.TASK_DISPLAY_CLOCK_TIME_REGEX
import com.vvtech.aiassistant.features.assistant_tasks.TASK_DISPLAY_NATURAL_TIME_CLEANUP_REGEX
import com.vvtech.aiassistant.features.assistant_tasks.TASK_DISPLAY_NATURAL_TIME_REGEX
import com.vvtech.aiassistant.features.assistant_tasks.TASK_DISPLAY_TIME_REGEX
import com.vvtech.aiassistant.features.assistant_tasks.TaskDisplayTextStatusKind
import com.vvtech.aiassistant.features.assistant_tasks.TaskDisplayTimeFormatter
import com.vvtech.aiassistant.features.assistant_tasks.cleanTaskDisplayInfoSegment
import com.vvtech.aiassistant.features.assistant_tasks.compactTaskDisplayInfo
import com.vvtech.aiassistant.features.assistant_tasks.extractTaskDisplayFactSegments
import com.vvtech.aiassistant.features.assistant_tasks.extractTaskDisplayInstant
import com.vvtech.aiassistant.features.assistant_tasks.fallbackTaskDisplayTimeLabel
import com.vvtech.aiassistant.features.assistant_tasks.isTaskDisplayTimeOnlySegment
import com.vvtech.aiassistant.features.assistant_tasks.isUsefulTaskDisplayInfoSegment
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayChineseWeekday
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayCombinedText
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayContainsAny
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayDefaultTarget
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayHomeNotificationText
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayIsGenericTarget
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayKeyInfo
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayLooksLikeSceneLabel
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplaySanitizeTarget
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplaySceneName
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplaySceneTarget
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayTargetFromFreeText
import com.vvtech.aiassistant.features.assistant_tasks.taskDisplayTargetFromTitle
import com.vvtech.aiassistant.features.assistant_tasks.parseTaskDisplayTime
import com.vvtech.aiassistant.features.assistant_tasks.removeDuplicateRestaurantPartyNumbers as taskDisplayRemoveDuplicateRestaurantPartyNumbers
import com.vvtech.aiassistant.features.assistant_tasks.removeTaskDisplayTimeExpressions
import com.vvtech.aiassistant.features.assistant_tasks.splitTaskDisplayInfo
import java.time.Instant
import java.time.LocalDate


internal fun finalTaskCombinedText(vararg values: String?): String =
    taskDisplayCombinedText(*values)

internal fun finalTaskSceneName(sceneType: String?, text: String): String =
    taskDisplaySceneName(sceneType, text)

internal fun finalTaskSceneTarget(
    sceneName: String,
    title: String,
    detail: String,
    sourceText: String
): String = taskDisplaySceneTarget(sceneName, title, detail, sourceText)

internal fun finalTaskTargetFromTitle(sceneName: String, title: String): String =
    taskDisplayTargetFromTitle(sceneName, title)

internal fun finalTaskTargetFromFreeText(sceneName: String, text: String): String =
    taskDisplayTargetFromFreeText(sceneName, text)

internal fun looksLikeTaskSceneLabel(value: String, sceneName: String): Boolean =
    taskDisplayLooksLikeSceneLabel(value, sceneName)

internal fun sanitizeTaskTarget(sceneName: String, raw: String): String =
    taskDisplaySanitizeTarget(sceneName, raw)

internal fun isGenericTaskTarget(value: String): Boolean =
    taskDisplayIsGenericTarget(value)

internal fun defaultFinalTaskTarget(sceneName: String): String =
    taskDisplayDefaultTarget(sceneName)

internal fun finalTaskKeyInfo(
    sceneName: String,
    title: String,
    detail: String,
    sourceText: String
): String = taskDisplayKeyInfo(sceneName, title, detail, sourceText)

internal fun removeDuplicateRestaurantPartyNumbers(sceneName: String, segments: List<String>): List<String> {
    return taskDisplayRemoveDuplicateRestaurantPartyNumbers(sceneName, segments)
}

internal fun splitTaskInfo(text: String): List<String> =
    splitTaskDisplayInfo(text)

internal fun isUsefulTaskInfoSegment(segment: String, title: String): Boolean =
    isUsefulTaskDisplayInfoSegment(segment, title)

internal fun cleanTaskInfoSegment(segment: String): String =
    cleanTaskDisplayInfoSegment(segment)

internal fun removeFinalTaskTimeExpressions(value: String): String =
    removeTaskDisplayTimeExpressions(value)

internal fun isTaskTimeOnlySegment(value: String): Boolean =
    isTaskDisplayTimeOnlySegment(value)

internal fun compactTaskInfo(raw: String): String =
    compactTaskDisplayInfo(raw)

internal fun extractTaskFactSegments(text: String, sceneName: String): List<String> =
    extractTaskDisplayFactSegments(text, sceneName)

internal fun containsAny(text: String, values: List<String>): Boolean =
    taskDisplayContainsAny(text, values)

internal fun homeNotificationText(record: FinalTaskRecord): String {
    return homeNotificationText(record.toFinalTaskDisplayItem())
}

internal fun homeNotificationText(item: FinalTaskDisplayItem): String {
    return localizedFinalTaskText(taskDisplayHomeNotificationText(
        sceneName = item.sceneName,
        sceneTarget = item.sceneTarget,
        keyInfo = item.keyInfo,
        statusKind = item.statusKind.toTaskDisplayTextStatusKind()
    ))
}

private fun FinalTaskStatusKind.toTaskDisplayTextStatusKind(): TaskDisplayTextStatusKind = when (this) {
    FinalTaskStatusKind.Completed -> TaskDisplayTextStatusKind.Completed
    FinalTaskStatusKind.Incomplete -> TaskDisplayTextStatusKind.Incomplete
    FinalTaskStatusKind.Running -> TaskDisplayTextStatusKind.Running
    FinalTaskStatusKind.ExecutionError -> TaskDisplayTextStatusKind.ExecutionError
}

internal data class QueuedHomeNotificationItem(
    val item: FinalHomeNotificationItem,
    val sortInstant: Instant?,
    val originalIndex: Int
)

internal fun extractFinalTaskInstant(raw: String?): Instant? =
    extractTaskDisplayInstant(raw)

internal fun parseFinalTaskTime(value: String): Instant? =
    parseTaskDisplayTime(value)

internal fun fallbackFinalTaskTimeLabel(raw: String?): String =
    fallbackTaskDisplayTimeLabel(raw)

internal fun chineseWeekday(date: LocalDate): String =
    taskDisplayChineseWeekday(date)

internal val FinalTaskDisplayTimeFormatter = TaskDisplayTimeFormatter

internal val FINAL_TASK_TIME_REGEX = TASK_DISPLAY_TIME_REGEX

internal val FINAL_TASK_NATURAL_TIME_REGEX = TASK_DISPLAY_NATURAL_TIME_REGEX

internal val FINAL_TASK_CLOCK_TIME_REGEX = TASK_DISPLAY_CLOCK_TIME_REGEX

internal val FINAL_TASK_NATURAL_TIME_CLEANUP_REGEX = TASK_DISPLAY_NATURAL_TIME_CLEANUP_REGEX

internal val FINAL_TASK_CHINESE_CLOCK_TIME_CLEANUP_REGEX = TASK_DISPLAY_CHINESE_CLOCK_TIME_CLEANUP_REGEX

internal val FINAL_TASK_CLOCK_TIME_CLEANUP_REGEX = TASK_DISPLAY_CLOCK_TIME_CLEANUP_REGEX

internal val HOME_NOTIFICATION_TIME_REGEX = FINAL_TASK_TIME_REGEX
