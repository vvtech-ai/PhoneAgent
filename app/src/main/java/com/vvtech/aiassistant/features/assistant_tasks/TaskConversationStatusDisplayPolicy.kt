package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

internal enum class TaskConversationStatusKind(
    private val chineseLabel: String,
    private val englishLabel: String
) {
    Completed("已完成", "Completed"),
    Incomplete("未完成", "Incomplete"),
    Running("进行中", "In Progress"),
    ExecutionError("执行异常", "Execution Error");

    val label: String
        get() = currentAppText(chineseLabel, englishLabel)
}

internal fun canonicalConversationTaskStatus(status: String): String {
    val normalized = status.trim()
    val uppercase = normalized.uppercase(Locale.ROOT)
    return when {
        taskStatusHasTechnicalFailureSignal(normalized, uppercase) -> "EXECUTION_ERROR"
        uppercase.contains("USER_INTERRUPTED") -> "USER_INTERRUPTED"
        uppercase.contains("INCOMPLETE") || normalized == "未完成" -> "INCOMPLETE"
        uppercase.contains("COMPLET") || uppercase.contains("FINISH") || uppercase.contains("SUCCESS") ||
            normalized in setOf("已完成", "任务完成", "任务已完成") -> "COMPLETED"
        uppercase == "UNCLEAR" || normalized.contains("部分完成") -> "UNCLEAR"
        uppercase.contains("CLOSE") -> "CLOSED"
        uppercase.contains("CANCEL") || uppercase.contains("CANCELED") ||
            normalized in setOf("已取消", "已终止") -> "CANCELED"
        uppercase.contains("FAIL") || normalized == "失败" -> "FAILED"
        uppercase.contains("PENDING") || uppercase.contains("WAITING_CONFIRM") || normalized == "待确认" -> "RUNNING"
        uppercase.contains("ACTIVE") || uppercase.contains("RUNNING") || uppercase.contains("PROCESSING") ||
            uppercase.contains("WAITING") || normalized == "进行中" -> "RUNNING"
        else -> uppercase
    }
}

internal fun conversationStatusIsTerminal(status: String): Boolean {
    return status in setOf(
        "COMPLETED",
        "INCOMPLETE",
        "FAILED",
        "CANCELED",
        "CLOSED",
        "USER_INTERRUPTED",
        "NETWORK_ERROR",
        "EXECUTION_ERROR"
    )
}

internal fun conversationStatusIsPendingWithoutTerminalResult(status: String): Boolean {
    return status in setOf("PENDING", "READY", "READY_TO_EXECUTE", "WAITING", "WAITING_CONFIRM")
}

internal fun taskConversationStatusKind(status: String): TaskConversationStatusKind {
    val normalized = status.trim()
    val uppercase = normalized.uppercase(Locale.ROOT)
    return when {
        taskStatusHasTechnicalFailureSignal(normalized, uppercase) -> TaskConversationStatusKind.ExecutionError
        taskStatusNeedsUserConfirmationSignal(normalized, uppercase) -> TaskConversationStatusKind.Incomplete
        uppercase.contains("COMPLET") ||
            uppercase.contains("SUCCESS") ||
            uppercase.contains("DONE") ||
            normalized.contains("完成") ||
            normalized.contains("成功") -> TaskConversationStatusKind.Completed
        uppercase.contains("PENDING") ||
            uppercase.contains("CONFIRM") ||
            normalized.contains("待确认") -> TaskConversationStatusKind.Running
        else -> TaskConversationStatusKind.Running
    }
}

internal fun taskStatusHasTechnicalFailureSignal(normalized: String, uppercase: String): Boolean {
    return uppercase.contains("NETWORK") ||
        uppercase.contains("TIMEOUT") ||
        uppercase.contains("SIP_ERROR") ||
        uppercase.contains("PHONE_AGENT_ERROR") ||
        uppercase.contains("MODEL_ERROR") ||
        uppercase.contains("SERVICE_UNAVAILABLE") ||
        uppercase.contains("HTTP_ERROR") ||
        uppercase == "ERROR" ||
        uppercase.endsWith("_ERROR") ||
        uppercase.contains("TECHNICAL") ||
        normalized.contains("网络异常") ||
        normalized.contains("网络错误") ||
        normalized.contains("执行异常") ||
        normalized.contains("模型服务异常") ||
        normalized.contains("外呼通道异常") ||
        normalized.contains("服务不可用") ||
        normalized.contains("连接失败") ||
        normalized.contains("真实 SIP 未启用") ||
        normalized.contains("phone agent 未 ready") ||
        normalized.contains("超时")
}

private fun taskStatusNeedsUserConfirmationSignal(normalized: String, uppercase: String): Boolean {
    return uppercase.contains("INCOMPLETE") ||
        uppercase.contains("FAIL") ||
        uppercase.contains("CANCEL") ||
        uppercase.contains("CANCELED") ||
        uppercase.contains("CLOSE") ||
        uppercase.contains("UNCLEAR") ||
        uppercase.contains("PARTIAL") ||
        uppercase.contains("NEEDS_RECALL") ||
        uppercase.contains("NO_ANSWER") ||
        uppercase.contains("BUSY") ||
        uppercase.contains("REJECTED") ||
        normalized.contains("未接电话") ||
        normalized.contains("被挂断") ||
        normalized.contains("未应邀") ||
        normalized.contains("未完成") ||
        normalized.contains("失败") ||
        normalized.contains("取消") ||
        normalized.contains("终止") ||
        normalized.contains("关闭") ||
        normalized.contains("结果未确认") ||
        normalized.contains("部分完成") ||
        normalized.contains("稍后回电") ||
        normalized.contains("稍后联系") ||
        normalized.contains("需重拨") ||
        normalized.contains("未接通") ||
        normalized.contains("没打通") ||
        normalized.contains("未订到") ||
        normalized.contains("没订到") ||
        normalized.contains("无空位") ||
        normalized.contains("满位") ||
        normalized.contains("补资料")
}

internal fun conversationStatusLabel(status: String): String = when (canonicalConversationTaskStatus(status)) {
    "ACTIVE" -> currentAppText("进行中", "In Progress")
    "RUNNING", "PENDING" -> currentAppText("进行中", "In Progress")
    "INCOMPLETE" -> currentAppText("未完成", "Incomplete")
    "COMPLETED" -> currentAppText("已完成", "Completed")
    "NETWORK_ERROR", "EXECUTION_ERROR" -> currentAppText("执行异常", "Execution Error")
    "CLOSED", "FAILED", "UNCLEAR", "CANCELED" -> currentAppText("未完成", "Incomplete")
    "USER_INTERRUPTED" -> currentAppText("进行中", "In Progress")
    else -> taskConversationStatusKind(status).label
}

internal fun taskStatusDisplayLabel(status: String): String {
    return taskConversationStatusKind(status).label
}

internal fun isCompletedConversationStatus(status: String): Boolean {
    return canonicalConversationTaskStatus(status) == "COMPLETED"
}

internal fun isReadOnlyConversationStatus(status: String): Boolean {
    return canonicalConversationTaskStatus(status) == "CLOSED"
}

internal fun backendTaskStatusLabel(status: String): String = when (status.uppercase(Locale.ROOT)) {
    "SUCCESS", "COMPLETED" -> currentAppText("已完成", "Completed")
    "NETWORK_ERROR", "EXECUTION_ERROR", "NETWORK", "TIMEOUT", "SIP_ERROR", "PHONE_AGENT_ERROR",
    "MODEL_ERROR", "SERVICE_UNAVAILABLE" -> currentAppText("执行异常", "Execution Error")
    "FAILED", "INCOMPLETE", "UNCLEAR", "PARTIAL", "NEEDS_RECALL", "CANCELLED", "CANCELED",
    "CLOSED" -> currentAppText("未完成", "Incomplete")
    "CALLING", "RUNNING", "PROCESSING", "EXECUTING", "WAITING_EXTERNAL_RESULT" -> currentAppText("进行中", "In Progress")
    "CONFIRMING", "PENDING", "WAITING_CONFIRM", "READY", "READY_TO_EXECUTE" -> currentAppText("进行中", "In Progress")
    "INIT", "SCENE_IDENTIFIED", "COLLECTING_REQUIRED_INFO", "USER_MODIFIED_REQUEST",
    "USER_INTERRUPTED" -> currentAppText("进行中", "In Progress")
    else -> taskConversationStatusKind(status).label
}
