package com.vvtech.aiassistant.features.assistant_tasks

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

internal fun taskDisplayRecordSortInstant(
    startedAt: String,
    detail: String,
    sourceText: String,
    title: String,
    scheduledAt: String
): Instant? {
    return listOf(startedAt, detail, sourceText, title, scheduledAt)
        .firstNotNullOfOrNull { extractTaskDisplayInstant(it) }
}

internal fun taskDisplaySortEpochMillis(sortInstant: Instant?): Long {
    return sortInstant?.toEpochMilli() ?: Long.MIN_VALUE
}

internal fun taskDisplayRelativeTimeLabel(
    raw: String?,
    today: LocalDate = LocalDate.now(),
    zoneId: ZoneId = ZoneId.systemDefault()
): String {
    val instant = extractTaskDisplayInstant(raw) ?: return fallbackTaskDisplayTimeLabel(raw)
    val dateTime = LocalDateTime.ofInstant(instant, zoneId)
    val date = dateTime.toLocalDate()
    val time = dateTime.format(TaskDisplayTimeFormatter)
    val dayLabel = when {
        date == today -> "今天"
        date == today.minusDays(1) -> "昨天"
        date.isAfter(today.minusDays(7)) -> taskDisplayChineseWeekday(date)
        date.year == today.year -> "${date.monthValue}月${date.dayOfMonth}日"
        else -> "${date.year}年${date.monthValue}月${date.dayOfMonth}日"
    }
    return "$dayLabel $time"
}

internal fun taskDisplayStartTimeLabel(startedAt: String, combinedText: String): String {
    val explicitStart = startedAt.trim()
    if (explicitStart.isNotBlank()) {
        return taskDisplayRelativeTimeLabel(explicitStart)
    }
    return taskDisplayTimeCandidates(combinedText).firstOrNull()?.label
        ?: fallbackTaskDisplayTimeLabel(combinedText)
}

internal fun taskDisplayAppointmentTimeLabel(
    scheduledAt: String,
    combinedText: String,
    startTimeLabel: String
): String {
    val explicitSchedule = scheduledAt.trim()
    if (explicitSchedule.isNotBlank()) {
        return taskDisplayRelativeTimeLabel(explicitSchedule)
            .takeUnless { it == fallbackTaskDisplayTimeLabel(explicitSchedule) }
            ?: explicitSchedule
    }
    return taskDisplayTimeCandidates(combinedText)
        .map { it.label }
        .firstOrNull { it.isNotBlank() && it != startTimeLabel }
        .orEmpty()
}

private data class TaskDisplayTimeCandidate(
    val index: Int,
    val label: String,
    val range: IntRange
)

private fun taskDisplayTimeCandidates(raw: String?): List<TaskDisplayTimeCandidate> {
    if (raw.isNullOrBlank()) return emptyList()
    val candidates = mutableListOf<TaskDisplayTimeCandidate>()
    TASK_DISPLAY_TIME_REGEX.findAll(raw).forEach { match ->
        candidates += TaskDisplayTimeCandidate(
            index = match.range.first,
            label = taskDisplayRelativeTimeLabel(match.value),
            range = match.range
        )
    }
    TASK_DISPLAY_NATURAL_TIME_REGEX.findAll(raw).forEach { match ->
        if (candidates.none { it.range.overlaps(match.range) }) {
            candidates += TaskDisplayTimeCandidate(
                index = match.range.first,
                label = normalizeTaskDisplayTimeText(match.value),
                range = match.range
            )
        }
    }
    TASK_DISPLAY_CLOCK_TIME_REGEX.findAll(raw).forEach { match ->
        if (candidates.none { it.range.overlaps(match.range) }) {
            candidates += TaskDisplayTimeCandidate(
                index = match.range.first,
                label = normalizeTaskDisplayTimeText(match.value),
                range = match.range
            )
        }
    }
    return candidates
        .sortedBy { it.index }
        .distinctBy { it.label }
}

private fun IntRange.overlaps(other: IntRange): Boolean {
    return first <= other.last && other.first <= last
}

internal fun normalizeTaskDisplayTimeText(value: String): String {
    val normalized = value
        .replace('\uff1a', ':')
        .replace(Regex("""\s+"""), " ")
        .trim()
    return Regex("(点)\\s*([0-9])$").replace(normalized) { match ->
        match.groupValues[1]
    }
}

internal fun extractTaskDisplayInstant(raw: String?): Instant? {
    if (raw.isNullOrBlank()) return null
    val match = TASK_DISPLAY_TIME_REGEX.find(raw) ?: return null
    return parseTaskDisplayTime(match.value)
}

internal fun parseTaskDisplayTime(value: String): Instant? {
    val normalized = value.trim()
        .replace(' ', 'T')
        .let { timeText ->
            Regex("""([+-]\d{2})(\d{2})$""").replace(timeText) { match ->
                "${match.groupValues[1]}:${match.groupValues[2]}"
            }
        }
    return runCatching { Instant.parse(normalized) }.getOrNull()
        ?: runCatching { OffsetDateTime.parse(normalized).toInstant() }.getOrNull()
        ?: runCatching {
            LocalDateTime.parse(normalized, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                .atZone(ZoneId.systemDefault())
                .toInstant()
        }.getOrNull()
}

internal fun fallbackTaskDisplayTimeLabel(raw: String?): String {
    val value = raw.orEmpty().trim()
    if (value.isBlank()) return "时间待同步"
    Regex("""(?:今天|昨天|前天|明天|后天|周[一二三四五六日天]|星期[一二三四五六日天])\s*\d{0,2}(?::|：|点)?\d{0,2}""")
        .find(value)
        ?.value
        ?.trim()
        ?.takeIf { it.isNotBlank() }
        ?.let { return it }
    return "时间待同步"
}

internal fun taskDisplayChineseWeekday(date: LocalDate): String = when (date.dayOfWeek.value) {
    1 -> "星期一"
    2 -> "星期二"
    3 -> "星期三"
    4 -> "星期四"
    5 -> "星期五"
    6 -> "星期六"
    else -> "星期日"
}

internal val TaskDisplayTimeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

internal val TASK_DISPLAY_TIME_REGEX =
    Regex("""\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?""")

internal val TASK_DISPLAY_NATURAL_TIME_REGEX =
    Regex("""(?:今天|今晚|明天|明晚|后天|周[一二三四五六日天]|星期[一二三四五六日天])\s*\d{1,2}(?:(?::|：)\d{1,2}|点(?:\d{1,2}分?)?)?""")

internal val TASK_DISPLAY_CLOCK_TIME_REGEX =
    Regex("""(?<![\d:-])\d{1,2}(?::|：)\d{2}(?![:\d])""")

internal val TASK_DISPLAY_NATURAL_TIME_CLEANUP_REGEX =
    Regex("""(?:今天|今晚|明天|明晚|后天|周[一二三四五六日天]|星期[一二三四五六日天])\s*\d{1,2}(?:(?::|：)[0-5]\d|点(?:半|[0-5]?\d分|[0-5]\d)?)?""")

internal val TASK_DISPLAY_CHINESE_CLOCK_TIME_CLEANUP_REGEX =
    Regex("(?<!\\d)\\d{1,2}\\s*点(?:半|[0-5]?\\d分|[0-5]\\d)?")

internal val TASK_DISPLAY_CLOCK_TIME_CLEANUP_REGEX =
    Regex("""(?<![\d:-])\d{1,2}(?::|：)[0-5]\d(?![:\d])""")
