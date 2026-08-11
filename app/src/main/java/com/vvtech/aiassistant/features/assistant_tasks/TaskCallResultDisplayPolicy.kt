package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.StatusStyle
import java.util.Locale

internal enum class CallDisplayOutcome {
    Completed,
    Failed,
    Cancelled,
    Unclear
}

internal data class CallSessionDisplayDecision(
    val outcome: CallDisplayOutcome,
    val taskStatus: String,
    val statusText: String,
    val historyStatus: String,
    val historyStyle: StatusStyle
)

internal data class CallSessionTerminalDisplayPlan(
    val historyStatus: String,
    val historyStyle: StatusStyle,
    val taskStatus: String,
    val statusText: String
)

internal fun callResultTaskStatus(result: CallResultPayload?): String {
    if (callResultOutcome(result) == CallDisplayOutcome.Completed) return "COMPLETED"
    return if (callResultHasTechnicalFailure(result)) "EXECUTION_ERROR" else "INCOMPLETE"
}

internal fun callResultStatusText(result: CallResultPayload?, sceneType: String? = null): String {
    return when (callResultOutcome(result)) {
        CallDisplayOutcome.Completed -> {
            if (callDisplayIsBookingScene(sceneType)) "任务完成" else "完成"
        }
        CallDisplayOutcome.Cancelled -> callResultFailureLabel(result)
        CallDisplayOutcome.Failed -> callResultFailureLabel(result)
        CallDisplayOutcome.Unclear -> "结果未确认"
    }
}

internal fun callResultOutcome(result: CallResultPayload?): CallDisplayOutcome {
    if (result == null) return CallDisplayOutcome.Unclear
    val agentOutcome = normalizedAgentOutcome(result.metadata)
    when (agentOutcome) {
        "SUCCESS" -> return CallDisplayOutcome.Completed
        "USER_CANCELLED", "USER_CANCELED" -> return CallDisplayOutcome.Cancelled
        "FAILED", "NEEDS_RECALL" -> return CallDisplayOutcome.Failed
        "UNCLEAR" -> return CallDisplayOutcome.Unclear
    }
    val resultCode = normalized(result.metadata?.get("resultCode"))
    if (resultCode == "SUCCESS_CONFIRMED") return CallDisplayOutcome.Completed
    if (resultCodeHasFailureSignal(resultCode)) return CallDisplayOutcome.Failed
    if (resultCode == "INCOMPLETE_OR_UNCLEAR") return CallDisplayOutcome.Unclear
    val status = normalized(result.status)
    return when (status) {
        "CANCELLED", "CANCELED", "USER_CANCELLED", "USER_CANCELED", "USER_INTERRUPTED" -> CallDisplayOutcome.Cancelled
        "COMPLETED", "SUCCESS", "DONE", "FINISHED" -> {
            if (callResultTextHasFailureSignal(result)) {
                CallDisplayOutcome.Failed
            } else {
                CallDisplayOutcome.Unclear
            }
        }
        "FAILED", "ERROR", "FAIL" -> CallDisplayOutcome.Failed
        else -> CallDisplayOutcome.Unclear
    }
}

internal fun shouldClearCallResultForContinuation(
    @Suppress("UNUSED_PARAMETER") taskStatus: String?,
    result: CallResultPayload?
): Boolean {
    if (result == null) return false
    return true
}

internal fun callSessionDisplayDecision(response: CallSessionStatusResponse): CallSessionDisplayDecision {
    val callState = normalized(response.callState)
    val handoffMode = normalized(response.handoffMode)
    val resultCode = normalized(response.resultCode)
    val bookingScene = callDisplayIsBookingScene(response.sceneType)
    val executionError = callSessionHasTechnicalFailure(response)
    val failureLabel = if (executionError) "执行异常" else "未完成"

    val outcome = when {
        callState in setOf("CANCELLED", "CANCELED") ||
            resultCode in setOf("CANCELLED", "CANCELED", "USER_CANCELLED", "USER_CANCELED", "CALL_CANCELLED", "CALL_CANCELED") ->
            CallDisplayOutcome.Cancelled

        resultCode == "SUCCESS_CONFIRMED" ->
            CallDisplayOutcome.Completed

        callState in setOf("FAILED", "NOT_FOUND") ||
            handoffMode == "FAILED" ||
            resultCodeHasFailureSignal(resultCode) ->
            CallDisplayOutcome.Failed

        resultCode == "INCOMPLETE_OR_UNCLEAR" ->
            CallDisplayOutcome.Unclear

        else -> CallDisplayOutcome.Unclear
    }

    val statusText = when (outcome) {
        CallDisplayOutcome.Completed -> {
            if (bookingScene) {
                "任务完成"
            } else {
                response.resultText.takeIf { it.isNotBlank() }
                    ?: response.resultReason.takeIf { it.isNotBlank() }
                    ?: response.statusMessage.takeIf { it.isNotBlank() }
                    ?: "任务完成"
            }
        }
        CallDisplayOutcome.Cancelled,
        CallDisplayOutcome.Failed -> failureLabel
        CallDisplayOutcome.Unclear -> "结果未确认"
    }

    val historyStatus = when (outcome) {
        CallDisplayOutcome.Completed -> "任务完成"
        CallDisplayOutcome.Cancelled,
        CallDisplayOutcome.Failed -> failureLabel
        CallDisplayOutcome.Unclear -> "结果未确认"
    }

    return CallSessionDisplayDecision(
        outcome = outcome,
        taskStatus = when {
            outcome == CallDisplayOutcome.Completed -> "COMPLETED"
            executionError -> "EXECUTION_ERROR"
            else -> "INCOMPLETE"
        },
        statusText = statusText,
        historyStatus = historyStatus,
        historyStyle = if (outcome == CallDisplayOutcome.Completed) StatusStyle.Success else StatusStyle.Failure
    )
}

internal fun callSessionTerminalDisplayPlan(
    response: CallSessionStatusResponse,
    existingHistoryStatus: String?,
    currentCallUiMode: CallUiMode
): CallSessionTerminalDisplayPlan {
    val displayDecision = callSessionDisplayDecision(response)
    val humanTakeoverTerminal = existingHistoryStatus == "人工接管" || currentCallUiMode == CallUiMode.Human
    if (humanTakeoverTerminal) {
        return CallSessionTerminalDisplayPlan(
            historyStatus = "人工接管",
            historyStyle = StatusStyle.Success,
            taskStatus = "COMPLETED",
            statusText = "人工接管"
        )
    }
    return CallSessionTerminalDisplayPlan(
        historyStatus = displayDecision.historyStatus,
        historyStyle = displayDecision.historyStyle,
        taskStatus = displayDecision.taskStatus,
        statusText = displayDecision.statusText
    )
}

internal fun callPageResultStatusFromSource(
    status: String,
    detailSource: String,
    @Suppress("UNUSED_PARAMETER") sceneType: String? = null
): String {
    val raw = status.trim()
    if (raw.isBlank()) return "通话已结束"
    val upper = raw.uppercase(Locale.ROOT)
    val technicalSource = "$raw\n$detailSource"
    if (taskStatusHasTechnicalFailureSignal(technicalSource, technicalSource.uppercase(Locale.ROOT))) {
        return "执行异常"
    }
    return when (upper) {
        "CANCELLED", "CANCELED", "USER_CANCELLED", "USER_CANCELED", "USER_INTERRUPTED",
        "FAILED", "ERROR", "FAIL", "INCOMPLETE", "UNCLEAR",
        "已取消", "未完成", "失败" -> "未完成"
        "COMPLETED", "SUCCESS", "DONE", "FINISHED" -> "结果未确认"
        else -> if (looksLikeTerminalCallResultStatus(raw)) raw else raw
    }
}

internal fun looksLikeTerminalCallResultStatus(status: String): Boolean {
    val normalizedStatus = status.trim()
    if (normalizedStatus.isBlank()) return false
    return Regex(
        "已结束|通话已结束|AI代打完成|预订成功|预约成功|已预订|未完成|失败|已取消|执行异常|任务部分完成|结果未确认|FAILED|COMPLETED|CANCELLED|CANCELED|EXECUTION_ERROR",
        RegexOption.IGNORE_CASE
    ).containsMatchIn(normalizedStatus)
}

internal fun callDisplayIsBookingScene(sceneType: String?, source: String = ""): Boolean {
    val normalizedScene = normalized(sceneType)
    if (normalizedScene in setOf("FOOD_ORDERING", "HOTEL_BOOKING", "FOOD", "HOTEL")) return true
    val sourceLooksBooking = source.looksLikeBookingSource()
    if (normalizedScene in setOf("AI_CALL", "CALL", "PHONE_CALL", "GENERAL", "MESSAGE_RELAY", "MEETING_NOTIFICATION")) {
        return sourceLooksBooking
    }
    return sourceLooksBooking
}

internal fun callDisplayBookingTargetLabel(sceneType: String?, source: String = ""): String {
    val normalizedScene = normalized(sceneType)
    return when {
        normalizedScene in setOf("HOTEL_BOOKING", "HOTEL") ||
            Regex("酒店|宾馆|入住|离店|房型").containsMatchIn(source) -> "酒店"
        else -> "餐厅"
    }
}

private fun normalizedAgentOutcome(metadata: Map<String, String>?): String {
    if (metadata.isNullOrEmpty()) return ""
    val keys = listOf("agentOutcome", "reportCallOutcome", "callOutcome", "outcome", "agent_outcome")
    return keys
        .asSequence()
        .mapNotNull { key -> metadata[key]?.trim()?.takeIf { it.isNotBlank() } }
        .firstOrNull()
        ?.uppercase(Locale.ROOT)
        .orEmpty()
}

private fun String.looksLikeBookingSource(): Boolean {
    if (isBlank()) return false
    return Regex("订餐|订座|订位|餐厅|饭店|酒店|宾馆|入住|离店|预订|预约|预留|包房|包间|房型")
        .containsMatchIn(this)
}

private fun resultCodeHasFailureSignal(resultCode: String): Boolean {
    if (resultCode.isBlank()) return false
    return resultCode.startsWith("FAILED") ||
        resultCode in setOf(
            "CALL_FAILED",
            "CALL_INTERRUPTED",
            "NO_EFFECTIVE_DIALOGUE",
            "NO_ANSWER",
            "BUSY",
            "REJECTED",
            "TIMEOUT",
            "MERCHANT_REQUESTED_CALLBACK"
        )
}

private fun callResultTextHasFailureSignal(result: CallResultPayload): Boolean {
    val text = listOf(
        result.headline,
        result.detail,
        result.metadata?.get("agentReason").orEmpty(),
        result.metadata?.get("resultReason").orEmpty()
    ).joinToString("\n")
    if (text.isBlank()) return false
    return Regex(
        "(?i)\\b(FAILED|FAIL|ERROR|INCOMPLETE|NO_ANSWER|REJECTED|TIMEOUT)\\b|" +
            "任务失败|未完成|失败|未成功|未订到|没订到|没有订到|未接通|无人接听|无空位|满位|拒绝|无法完成|稍后再联系"
    ).containsMatchIn(text)
}

private fun callResultFailureLabel(result: CallResultPayload?): String =
    if (callResultHasTechnicalFailure(result)) "执行异常" else "未完成"

private fun callResultHasTechnicalFailure(result: CallResultPayload?): Boolean {
    if (result == null) return false
    if (callResultHasExplicitBusinessOutcome(result)) return false
    val source = buildList {
        add(result.status)
        add(result.headline)
        add(result.detail)
        result.metadata?.values?.let(::addAll)
    }.joinToString("\n")
    return taskStatusHasTechnicalFailureSignal(source, source.uppercase(Locale.ROOT))
}

private fun callResultHasExplicitBusinessOutcome(result: CallResultPayload): Boolean {
    val agentOutcome = normalizedAgentOutcome(result.metadata)
    if (agentOutcome in setOf("FAILED", "UNCLEAR", "NEEDS_RECALL", "USER_CANCELLED", "USER_CANCELED")) {
        return true
    }
    val resultCode = normalized(result.metadata?.get("resultCode"))
    if (resultCode.contains("NO_ANSWER") ||
        resultCode.contains("BUSY") ||
        resultCode.contains("REJECTED") ||
        resultCode.contains("USER_CANCEL") ||
        resultCode == "INCOMPLETE_OR_UNCLEAR" ||
        resultCode == "MERCHANT_REQUESTED_CALLBACK"
    ) {
        return true
    }
    val terminationCause = normalized(result.metadata?.get("terminationCause"))
    return terminationCause in setOf("REMOTE_BYE", "USER_CANCELLED", "USER_CANCELED")
}

private fun callSessionHasTechnicalFailure(response: CallSessionStatusResponse): Boolean {
    val resultCode = normalized(response.resultCode)
    if (resultCode.contains("NO_ANSWER") ||
        resultCode.contains("BUSY") ||
        resultCode.contains("REJECTED") ||
        resultCode.contains("USER_CANCEL") ||
        resultCode == "INCOMPLETE_OR_UNCLEAR" ||
        resultCode == "MERCHANT_REQUESTED_CALLBACK"
    ) {
        return false
    }
    val source = listOf(
        response.callState,
        response.handoffMode,
        response.resultCode,
        response.resultReason,
        response.resultText,
        response.statusMessage
    ).joinToString("\n")
    return taskStatusHasTechnicalFailureSignal(source, source.uppercase(Locale.ROOT))
}

private fun normalized(value: String?): String = value?.trim()?.uppercase(Locale.ROOT).orEmpty()

private fun String.looksGenericEnded(): Boolean {
    val normalized = trim()
    return normalized in setOf("通话已结束", "电话已结束", "任务完成", "任务已完成", "已完成")
}
