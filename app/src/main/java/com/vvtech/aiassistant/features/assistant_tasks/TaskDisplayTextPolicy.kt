package com.vvtech.aiassistant.features.assistant_tasks

import java.util.Locale

internal enum class TaskDisplayTextStatusKind {
    Completed,
    Incomplete,
    Running,
    ExecutionError
}

internal fun taskDisplayCombinedText(vararg values: String?): String {
    return values
        .map { it.orEmpty().trim() }
        .filter { it.isNotBlank() }
        .joinToString(" · ")
}

internal fun taskDisplaySkillSceneName(skillId: String?): String? = when (skillId?.trim()) {
    "restaurant_booking" -> "订餐厅"
    "meeting_notification" -> "会议邀请"
    "business_event_invitation" -> "活动邀约"
    "batch_invitation" -> "批量邀约"
    "apology_master" -> "道歉"
    "parking_move_request" -> "挪车"
    "general_message_relay" -> "转达留言"
    "hotel_booking" -> "订酒店"
    "flight_booking" -> "订机票"
    else -> null
}

internal fun taskDisplaySceneName(sceneType: String?, text: String): String {
    val normalizedScene = sceneType.orEmpty().uppercase(Locale.ROOT)
    val normalizedText = text.lowercase(Locale.ROOT)
    return when {
        normalizedScene in setOf("FOOD_ORDERING", "RESTAURANT_BOOKING") -> "订餐厅"
        normalizedScene == "HOTEL_BOOKING" -> "订酒店"
        normalizedScene == "FLIGHT_BOOKING" -> "订机票"
        normalizedScene.contains("MEETING") -> "会议通知"
        normalizedScene == "AI_CALL" -> "AI 通话"
        taskDisplayContainsAny(normalizedText, listOf("会议", "参会", "回执", "邀请", "通知")) -> "会议通知"
        taskDisplayContainsAny(normalizedText, listOf("酒店", "入住", "离店", "房型", "无烟房")) -> "订酒店"
        taskDisplayContainsAny(normalizedText, listOf("机票", "航班", "出发", "目的地", "舱位")) -> "订机票"
        taskDisplayContainsAny(normalizedText, listOf("餐厅", "订餐", "订位", "包房", "包间", "低消", "海底捞", "新荣记", "西堤")) -> "订餐厅"
        else -> "AI 通话"
    }
}

internal fun taskDisplaySceneTarget(
    sceneName: String,
    title: String,
    detail: String,
    sourceText: String
): String {
    return listOf(
        taskDisplayTargetFromTitle(sceneName, title),
        taskDisplayTargetFromFreeText(sceneName, sourceText),
        taskDisplayTargetFromFreeText(sceneName, detail)
    ).firstOrNull { it.isNotBlank() } ?: taskDisplayDefaultTarget(sceneName)
}

internal fun taskDisplayTargetFromTitle(sceneName: String, title: String): String {
    val normalizedTitle = title.trim()
    if (normalizedTitle.isBlank()) return ""
    val parts = normalizedTitle
        .split("·")
        .map { it.trim() }
        .filter { it.isNotBlank() }
    val candidate = if (parts.size > 1) {
        if (taskDisplayLooksLikeSceneLabel(parts.first(), sceneName)) {
            parts.drop(1).joinToString(" · ")
        } else {
            parts.joinToString(" · ")
        }
    } else {
        normalizedTitle
    }
    return taskDisplaySanitizeTarget(sceneName, candidate)
}

internal fun taskDisplayTargetFromFreeText(sceneName: String, text: String): String {
    val normalizedText = text.trim()
    if (normalizedText.isBlank()) return ""
    if (sceneName == "会议通知") {
        Regex("""\d+\s*位参会人""").find(normalizedText)?.value?.let {
            return taskDisplaySanitizeTarget(sceneName, it)
        }
    }
    Regex("""([\u4e00-\u9fa5A-Za-z0-9·-]{2,20}(?:店|餐厅|酒店|牛排|火锅|会议|周会))""")
        .find(normalizedText)
        ?.value
        ?.let { return taskDisplaySanitizeTarget(sceneName, it) }
    return ""
}

internal fun taskDisplayLooksLikeSceneLabel(value: String, sceneName: String): Boolean {
    val normalized = value.replace(" ", "")
    val scene = sceneName.replace(" ", "")
    return normalized == scene ||
        normalized.contains("任务") ||
        normalized in setOf("订餐厅", "订餐", "订酒店", "酒店预订", "订机票", "会议通知", "会议邀请", "AI通话")
}

internal fun taskDisplaySanitizeTarget(sceneName: String, raw: String): String {
    var value = raw.trim()
        .trim(' ', '：', ':', '-', '—', '·')
        .replace(Regex("""^(请帮我|帮我|我要|我想|需要|帮忙)\s*"""), "")
        .replace(Regex("""^(订餐任务|订餐厅|订餐|订酒店任务|订酒店|酒店任务|订机票任务|订机票|会议通知|会议邀请|AI\s*通话任务|AI\s*任务)\s*"""), "")
        .trim(' ', '：', ':', '-', '—', '·')
    if (value.startsWith(sceneName)) {
        value = value.removePrefix(sceneName).trim(' ', '：', ':', '-', '—', '·')
    }
    value = value
        .split("。", "，", "；", ";", "\n")
        .firstOrNull()
        .orEmpty()
        .trim()
    if (taskDisplayIsGenericTarget(value)) return ""
    return value.take(22)
}

internal fun taskDisplayIsGenericTarget(value: String): Boolean {
    if (value.isBlank()) return true
    if (value in setOf("餐厅", "酒店", "任务", "目标对象", "进行中的对话")) return true
    if (value.contains("正在同步") || value.contains("同步失败") || value.contains("点击继续")) return true
    if (TASK_DISPLAY_TIME_REGEX.matches(value)) return true
    return false
}

internal fun taskDisplayDefaultTarget(sceneName: String): String = when (sceneName) {
    "订餐厅" -> "餐厅"
    "订酒店" -> "酒店"
    "订机票" -> "航班"
    "会议通知" -> "参会人"
    else -> "目标对象"
}

internal fun taskDisplayKeyInfo(
    sceneName: String,
    title: String,
    detail: String,
    sourceText: String
): String {
    val combined = taskDisplayCombinedText(detail, sourceText, title)
    val candidates = buildList {
        splitTaskDisplayInfo(detail).filterTo(this) { isUsefulTaskDisplayInfoSegment(it, title) }
        extractTaskDisplayFactSegments(combined, sceneName).forEach(::add)
        splitTaskDisplayInfo(sourceText).filterTo(this) { isUsefulTaskDisplayInfoSegment(it, title) }
    }
    val compact = candidates
        .map { cleanTaskDisplayInfoSegment(removeTaskDisplayTimeExpressions(it)) }
        .filter { it.isNotBlank() }
        .filterNot { isTaskDisplayTimeOnlySegment(it) }
        .let { removeDuplicateRestaurantPartyNumbers(sceneName, it) }
        .distinct()
        .take(4)
        .joinToString(" · ")
    if (compact.isNotBlank()) return compact
    return compactTaskDisplayInfo(detail)
        .ifBlank { compactTaskDisplayInfo(sourceText) }
        .ifBlank { "任务信息已同步" }
}

internal fun removeDuplicateRestaurantPartyNumbers(sceneName: String, segments: List<String>): List<String> {
    if (sceneName != "订餐厅") return segments
    val normalizedPartyCounts = segments.mapNotNull { segment ->
        Regex("""^(\d+)\s*(?:位|人|名)$""").matchEntire(segment.trim())?.groupValues?.get(1)
    }.toSet()
    if (normalizedPartyCounts.isEmpty()) return segments
    return segments.filterNot { it.trim() in normalizedPartyCounts }
}

internal fun splitTaskDisplayInfo(text: String): List<String> {
    return text
        .replace("\n", "·")
        .replace("；", "·")
        .replace(";", "·")
        .replace("。", "·")
        .split("·")
        .map { it.trim() }
        .filter { it.isNotBlank() }
}

internal fun isUsefulTaskDisplayInfoSegment(segment: String, title: String): Boolean {
    val value = segment.trim()
    if (value.isBlank() || value == title.trim()) return false
    if (TASK_DISPLAY_TIME_REGEX.containsMatchIn(value)) return false
    if (isTaskDisplayTimeOnlySegment(value)) return false
    if (value.contains("任务已同步") || value.contains("任务已提交") || value.contains("等待进一步处理")) return false
    if (value.length > 36 && !taskDisplayContainsAny(value, listOf("未接通", "无人接听", "已预订", "已确认", "包房", "低消"))) {
        return false
    }
    return true
}

internal fun cleanTaskDisplayInfoSegment(segment: String): String {
    return segment
        .replace(Regex("""^(详情|结果|任务结果|关键信息|摘要)[:：]\s*"""), "")
        .replace(Regex("""\s+"""), " ")
        .trim()
        .take(36)
}

internal fun removeTaskDisplayTimeExpressions(value: String): String {
    return listOf(
        TASK_DISPLAY_TIME_REGEX,
        TASK_DISPLAY_NATURAL_TIME_CLEANUP_REGEX,
        TASK_DISPLAY_CHINESE_CLOCK_TIME_CLEANUP_REGEX,
        TASK_DISPLAY_CLOCK_TIME_CLEANUP_REGEX
    ).fold(value) { current, regex ->
        regex.replace(current, " ")
    }
        .replace(Regex("""\s+"""), " ")
        .trim(' ', '\u00b7', '\u8def', ',', '\uff0c', ';', '\uff1b', ':', '\uff1a', '-', '\u3002')
}

internal fun isTaskDisplayTimeOnlySegment(value: String): Boolean {
    val normalized = normalizeTaskDisplayTimeText(value)
    return TASK_DISPLAY_TIME_REGEX.matches(normalized) ||
        TASK_DISPLAY_NATURAL_TIME_REGEX.matches(normalized) ||
        TASK_DISPLAY_CLOCK_TIME_REGEX.matches(normalized)
}

internal fun compactTaskDisplayInfo(raw: String): String {
    return cleanTaskDisplayInfoSegment(removeTaskDisplayTimeExpressions(raw))
        .takeIf { it.isNotBlank() && isUsefulTaskDisplayInfoSegment(it, "") }
        .orEmpty()
}

internal fun extractTaskDisplayFactSegments(text: String, sceneName: String): List<String> {
    if (text.isBlank()) return emptyList()
    return buildList {
        Regex("""(?:今天|今晚|明天|明晚|后天|周[一二三四五六日天]|星期[一二三四五六日天])\s*(?:\d{1,2}(?::|：|点)\d{0,2})?""")
            .findAll(text)
            .map { it.value.trim() }
            .filter { it.isNotBlank() }
            .forEach(::add)
        Regex("""\d{1,2}[:：]\d{2}""").findAll(text).map { it.value }.forEach(::add)
        Regex("""\d{1,2}\s*点(?:半|\d{1,2}分?)?""").findAll(text).map { it.value.replace(" ", "") }.forEach(::add)
        Regex("""\d+\s*(?:位参会人|位|人|名)""").findAll(text).map { it.value.replace(" ", "") }.forEach(::add)

        listOf("包房", "包间", "大厅", "低消", "无烟房", "高楼层", "停车", "回执", "未接通", "无人接听", "已预订", "已确认")
            .filter { text.contains(it) }
            .forEach(::add)
        if (sceneName == "会议通知" && text.contains("参会")) add("确认回执")
    }
}

internal fun taskDisplayContainsAny(text: String, values: List<String>): Boolean {
    return values.any { text.contains(it, ignoreCase = true) }
}

internal fun taskDisplayHomeNotificationText(
    sceneName: String,
    sceneTarget: String,
    keyInfo: String,
    statusKind: TaskDisplayTextStatusKind
): String {
    val prefix = when (statusKind) {
        TaskDisplayTextStatusKind.Completed -> "${sceneName}已完成"
        TaskDisplayTextStatusKind.Incomplete -> "${sceneName}未完成"
        TaskDisplayTextStatusKind.Running -> "${sceneName}进行中"
        TaskDisplayTextStatusKind.ExecutionError -> "${sceneName}执行异常"
    }
    val body = listOf(sceneTarget, keyInfo)
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .distinct()
        .joinToString(" · ")
    return if (body.isBlank()) prefix else "$prefix：$body"
}
