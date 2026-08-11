package com.vvtech.aiassistant.features.assistant_tasks

import java.util.Locale

internal enum class TaskFinalResultStatusStyle {
    Success,
    Failure
}

internal data class TaskFinalResultSummaryInput(
    val task: String,
    val targetLabel: String,
    val target: String,
    val timeLabel: String,
    val time: String,
    val extra: String,
    val contactLabel: String? = null,
    val contactValue: String? = null,
    val detailLabel: String? = null,
    val detailValue: String? = null
)

internal data class TaskFinalResultCallInput(
    val name: String,
    val sub: String,
    val status: String,
    val transcriptTexts: List<String>
)

internal data class TaskFinalResultHistoryInput(
    val title: String,
    val status: String,
    val style: TaskFinalResultStatusStyle,
    val meta: String
)

internal data class TaskFinalResultPageState(
    val badge: String,
    val success: Boolean,
    val partial: Boolean = false,
    val title: String,
    val meta: String,
    val rows: List<TaskFinalResultInfoRow>
)

internal data class TaskFinalResultInfoRow(
    val label: String,
    val value: String
)

internal fun buildTaskFinalResultPageState(
    restaurantName: String,
    sceneType: String,
    summary: TaskFinalResultSummaryInput?,
    callData: TaskFinalResultCallInput,
    historyRecord: TaskFinalResultHistoryInput?
): TaskFinalResultPageState {
    val detailSource = taskFinalResultDetailSource(summary, callData, historyRecord)
    val statusText = listOf(
        historyRecord?.status.orEmpty(),
        callData.status
    ).firstOrNull { it.isNotBlank() }.orEmpty()
    val partial = taskFinalResultIsPartial(statusText)
    val success = !partial && taskFinalResultIsSuccess(statusText, detailSource, historyRecord?.style)
    val title = listOf(
        callData.name,
        restaurantName,
        summary?.target.orEmpty()
    ).firstOrNull { it.isNotBlank() } ?: "任务结果"
    val normalizedScene = taskFinalResultNormalizeScene(sceneType, summary, title, detailSource)
    val meta = taskFinalResultMeta(normalizedScene, callData, success)
    val primaryResult = taskFinalResultPrimaryResult(detailSource, statusText, success)
    val optionalRows = taskFinalResultOptionalRows(detailSource, summary)
    val remark = taskFinalResultRemark(
        detailSource,
        primaryResult,
        *optionalRows.map { it.value }.toTypedArray()
    )
    val rows = buildList {
        add(TaskFinalResultInfoRow(taskFinalResultPrimaryLabel(normalizedScene), taskFinalResultCompact(primaryResult, 34)))
        addAll(optionalRows.map { row ->
            row.copy(value = taskFinalResultCompact(row.value, 28))
        })
        add(TaskFinalResultInfoRow("备注", taskFinalResultCompact(remark, 42)))
    }
    val badge = when {
        partial -> "部分完成"
        success -> "已完成"
        else -> "未完成"
    }
    return TaskFinalResultPageState(
        badge = badge,
        success = success,
        partial = partial,
        title = title,
        meta = meta,
        rows = rows
    )
}

private fun taskFinalResultIsPartial(@Suppress("UNUSED_PARAMETER") statusText: String): Boolean {
    // UNCLEAR/部分完成 统一按完成展示，不再单列"部分完成"态。
    return false
}

private fun taskFinalResultNormalizeScene(
    sceneType: String,
    summary: TaskFinalResultSummaryInput?,
    title: String,
    detailSource: String
): String {
    val normalized = sceneType.trim().uppercase(Locale.ROOT)
    if (normalized.isNotBlank() && normalized != "GENERAL") return normalized
    val source = listOf(
        summary?.task.orEmpty(),
        summary?.targetLabel.orEmpty(),
        summary?.extra.orEmpty(),
        title,
        detailSource
    ).joinToString(" ")
    return when {
        Regex("餐厅|订餐|包间|包房|包厢|低消|restaurant", RegexOption.IGNORE_CASE).containsMatchIn(source) ->
            "FOOD_ORDERING"
        Regex("酒店|宾馆|民宿|客栈|入住|离店|hotel", RegexOption.IGNORE_CASE).containsMatchIn(source) ->
            "HOTEL_BOOKING"
        Regex("机票|航班|航空|舱位|出发|flight", RegexOption.IGNORE_CASE).containsMatchIn(source) ->
            "FLIGHT_BOOKING"
        else -> normalized.ifBlank { "GENERAL" }
    }
}

private fun taskFinalResultPrimaryLabel(sceneType: String): String = when (sceneType) {
    "FOOD_ORDERING", "RESTAURANT_BOOKING" -> "预订结果"
    "HOTEL_BOOKING" -> "订房结果"
    "FLIGHT_BOOKING" -> "订票结果"
    else -> "通话结果"
}

private fun taskFinalResultPrimaryResult(
    detailSource: String,
    statusText: String,
    success: Boolean
): String {
    val meaningful = taskFinalResultSentences(detailSource)
        .firstOrNull { it.length >= 4 }
        .orEmpty()
    return when {
        meaningful.isNotBlank() -> meaningful
        statusText.isNotBlank() -> statusText
        success -> "通话已完成"
        else -> "通话未完成"
    }
}

private fun taskFinalResultMeta(
    sceneType: String,
    callData: TaskFinalResultCallInput,
    success: Boolean
): String {
    val sceneLabel = when (sceneType) {
        "FOOD_ORDERING", "RESTAURANT_BOOKING" -> "订餐任务"
        "HOTEL_BOOKING" -> "酒店任务"
        "FLIGHT_BOOKING" -> "机票任务"
        else -> "AI 通话"
    }
    val status = if (success) "结果已整理" else "需要后续处理"
    return listOf(sceneLabel, callData.sub.trim(), status)
        .filter { it.isNotBlank() }
        .distinct()
        .joinToString(" · ")
}

private fun taskFinalResultOptionalRows(
    detailSource: String,
    summary: TaskFinalResultSummaryInput?
): List<TaskFinalResultInfoRow> {
    val rows = mutableListOf<TaskFinalResultInfoRow>()
    if (!summary?.target.isNullOrBlank()) {
        rows += TaskFinalResultInfoRow(summary?.targetLabel?.takeIf { it.isNotBlank() } ?: "对象", summary?.target.orEmpty())
    }
    if (!summary?.time.isNullOrBlank()) {
        rows += TaskFinalResultInfoRow(summary?.timeLabel?.takeIf { it.isNotBlank() } ?: "时间", summary?.time.orEmpty())
    }
    if (!summary?.contactValue.isNullOrBlank()) {
        rows += TaskFinalResultInfoRow(summary?.contactLabel?.takeIf { it.isNotBlank() } ?: "联系方式", summary?.contactValue.orEmpty())
    }
    if (!summary?.detailValue.isNullOrBlank()) {
        rows += TaskFinalResultInfoRow(summary?.detailLabel?.takeIf { it.isNotBlank() } ?: "补充信息", summary?.detailValue.orEmpty())
    }
    if (rows.isEmpty() && detailSource.isNotBlank()) {
        rows += TaskFinalResultInfoRow("摘要", taskFinalResultCompact(detailSource, 48))
    }
    return rows
}

private fun taskFinalResultDetailSource(
    summary: TaskFinalResultSummaryInput?,
    callData: TaskFinalResultCallInput,
    historyRecord: TaskFinalResultHistoryInput?
): String {
    return listOf(
        summary?.task.orEmpty(),
        summary?.target.orEmpty(),
        summary?.time.orEmpty(),
        summary?.extra.orEmpty(),
        summary?.contactValue.orEmpty(),
        summary?.detailValue.orEmpty(),
        callData.transcriptTexts.joinToString("。"),
        callData.status,
        historyRecord?.title.orEmpty(),
        historyRecord?.status.orEmpty(),
        historyRecord?.meta.orEmpty()
    )
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .distinct()
        .joinToString("。")
}

internal fun taskFinalResultIsSuccess(
    statusText: String,
    detailSource: String,
    style: TaskFinalResultStatusStyle?
): Boolean {
    if (style == TaskFinalResultStatusStyle.Success) return true
    if (taskFinalResultHasFailureSignal(statusText, detailSource, style)) return false
    val source = "$statusText $detailSource"
    return Regex(
        "(?i)\\bSUCCESS\\b|\\bCOMPLETED\\b|\\bUNCLEAR\\b|AI代打完成|代打完成|任务完成|任务已完成|已完成|通话已完成|部分完成|结果未确认|预订成功|预约成功|已订好|订好了|已传达|对方确认|成功|已订|已确认|已预订|已接通"
    ).containsMatchIn(source)
}

private fun taskFinalResultHasFailureSignal(
    statusText: String,
    detailSource: String,
    style: TaskFinalResultStatusStyle?
): Boolean {
    if (style == TaskFinalResultStatusStyle.Failure) return true
    val source = "$statusText $detailSource"
    return Regex(
        "(?i)\\bFAILED\\b|\\bCANCELLED\\b|失败|未完成|手动中止|中止|取消|未订到|没订到|没有订到|" +
            "预订未成功|预约未成功|未成功|没有成功|时间不匹配|座位条件不符|包房条件不符|" +
            "当前无空位|无空位|没有可预订|订满|满位|不满足|条件不符|稍后回电|稍后再联系|" +
            "无法从摘要|无法稳定判断|无法判断|未接通|异常"
    ).containsMatchIn(source)
}

private fun taskFinalResultSentences(source: String): List<String> {
    return source
        .replace(" | ", "。")
        .split('。', '；', ';', '\n')
        .map { it.trim(' ', '，', ',', '：', ':') }
        .filter { it.isNotBlank() }
}

private fun taskFinalResultRemark(
    detailSource: String,
    vararg usedValues: String
): String {
    val used = usedValues.filter { it.isNotBlank() }.toSet()
    return taskFinalResultSentences(detailSource)
        .firstOrNull { sentence -> used.none { it.contains(sentence) || sentence.contains(it) } }
        ?: "通话结果已同步到任务记录"
}

private fun taskFinalResultCompact(value: String, maxLength: Int): String {
    val normalized = value
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "未提及" }
    return if (normalized.length <= maxLength) {
        normalized
    } else {
        normalized.take(maxLength).trimEnd() + "..."
    }
}
