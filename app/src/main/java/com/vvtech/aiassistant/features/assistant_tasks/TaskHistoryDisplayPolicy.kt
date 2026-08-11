package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.ResultSummaryPayload
import com.vvtech.aiassistant.model.TaskListItem
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

internal enum class TaskHistoryStatusStyle {
    Success,
    Failure
}

internal data class TaskHistoryRecordDisplay(
    val title: String,
    val status: String,
    val style: TaskHistoryStatusStyle,
    val meta: String
)

internal fun summarizeTaskHistoryMeta(raw: String): String {
    val normalized = raw
        .replace("\r", "\n")
        .lineSequence()
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .joinToString(" ")
        .replace(Regex("\\s+"), " ")
        .trim()
    if (normalized.isBlank()) return ""
    if (Regex("(?i)(assistant|callee|system):").containsMatchIn(normalized)) {
        return "通话摘要已记录"
    }
    val firstSentence = normalized
        .split('。', '！', '？', ';', '；')
        .firstOrNull()
        ?.trim()
        .orEmpty()
    val candidate = if (firstSentence.isNotBlank()) firstSentence else normalized
    return candidate.take(48).trim()
}

internal fun normalizeTaskHistoryMeta(meta: String): String {
    val trimmed = meta.trim()
    if (trimmed.isBlank()) return trimmed
    val separator = " | "
    val splitIndex = trimmed.indexOf(separator)
    if (splitIndex <= 0) return summarizeTaskHistoryMeta(trimmed)
    val prefix = trimmed.substring(0, splitIndex).trim()
    val detail = trimmed.substring(splitIndex + separator.length)
    val summarized = summarizeTaskHistoryMeta(detail)
    return if (summarized.isBlank()) prefix else "$prefix | $summarized"
}

internal fun buildTaskCallHistoryMetaDetail(
    response: CallSessionStatusResponse,
    fallback: String
): String {
    return response.resultText.takeIf { it.isNotBlank() }
        ?: response.resultReason.takeIf { it.isNotBlank() }
        ?: response.statusMessage.takeIf { it.isNotBlank() }
        ?: fallback
}

internal fun taskHistorySortKey(item: TaskListItem): LocalDateTime {
    return runCatching { LocalDateTime.parse(item.createdAt) }.getOrElse { LocalDateTime.MIN }
}

internal fun buildTaskHistoryRecordDisplay(item: TaskListItem): TaskHistoryRecordDisplay {
    val style = if (item.status.equals("FAILED", ignoreCase = true)) {
        TaskHistoryStatusStyle.Failure
    } else {
        TaskHistoryStatusStyle.Success
    }
    val statusText = when (item.status.uppercase()) {
        "FAILED" -> "未完成"
        "SUCCESS", "COMPLETED" -> "已完成"
        else -> item.status
    }
    val createdText = runCatching {
        LocalDateTime.parse(item.createdAt).format(DateTimeFormatter.ofPattern("MM-dd HH:mm"))
    }.getOrDefault(item.createdAt)
    val detailText = summarizeTaskHistoryMeta(
        item.callResultText?.takeIf { it.isNotBlank() }
            ?: item.finalResult?.takeIf { it.isNotBlank() }
            ?: item.originText
    )
    return TaskHistoryRecordDisplay(
        title = item.originText.ifBlank { "已完成任务" },
        status = statusText,
        style = style,
        meta = "$createdText | $detailText"
    )
}

internal fun buildTaskResultSummaryStatus(result: ResultSummaryPayload): String {
    return "${result.headline} 路 ${result.status}"
}
