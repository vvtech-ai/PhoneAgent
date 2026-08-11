package com.vvtech.aiassistant.domain.task

import java.util.Locale

enum class TaskExecutionStatus(
    val wireValue: String,
    val isTerminal: Boolean,
    val isSuccessful: Boolean,
    val isRecoverable: Boolean = false
) {
    Init("INIT", isTerminal = false, isSuccessful = false),
    Active("ACTIVE", isTerminal = false, isSuccessful = false),
    Running("RUNNING", isTerminal = false, isSuccessful = false),
    Completed("COMPLETED", isTerminal = true, isSuccessful = true),
    Success("SUCCESS", isTerminal = true, isSuccessful = true),
    Incomplete("INCOMPLETE", isTerminal = true, isSuccessful = false),
    Failed("FAILED", isTerminal = true, isSuccessful = false),
    NetworkError("NETWORK_ERROR", isTerminal = false, isSuccessful = false, isRecoverable = true),
    ExecutionError("EXECUTION_ERROR", isTerminal = true, isSuccessful = false),
    Cancelled("CANCELLED", isTerminal = true, isSuccessful = false),
    Unknown("UNKNOWN", isTerminal = false, isSuccessful = false);

    companion object {
        fun fromRaw(raw: String?): TaskExecutionStatus {
            return when (taskStateToken(raw)) {
                "", "INIT", "IDLE" -> Init
                "ACTIVE", "PROCESSING", "CLARIFYING" -> Active
                "RUNNING", "IN_PROGRESS", "EXECUTING", "STARTED" -> Running
                "COMPLETED", "DONE", "FINISHED" -> Completed
                "SUCCESS", "SUCCEEDED" -> Success
                "INCOMPLETE", "PARTIAL", "PARTIALLY_COMPLETED", "NEEDS_FOLLOW_UP" -> Incomplete
                "FAILED", "FAIL", "ERROR" -> Failed
                "NETWORK_ERROR", "NETWORK", "NETWORK_FAILURE" -> NetworkError
                "EXECUTION_ERROR", "TOOL_ERROR" -> ExecutionError
                "CANCELLED", "CANCELED", "USER_CANCELLED", "USER_CANCELED", "USER_INTERRUPTED" -> Cancelled
                else -> Unknown
            }
        }
    }
}

data class NormalizedTaskExecutionStatus(
    val status: TaskExecutionStatus,
    val wireValue: String,
    val rawValue: String?
)

fun normalizeTaskExecutionStatus(raw: String?): NormalizedTaskExecutionStatus {
    val status = TaskExecutionStatus.fromRaw(raw)
    val rawValue = raw?.trim()?.takeIf { it.isNotBlank() }
    val normalizedRaw = taskStateToken(raw)
    val wireValue = if (status == TaskExecutionStatus.Unknown && normalizedRaw.isNotBlank()) {
        normalizedRaw
    } else {
        status.wireValue
    }
    return NormalizedTaskExecutionStatus(
        status = status,
        wireValue = wireValue,
        rawValue = rawValue
    )
}

fun normalizeTaskExecutionStatusWireValue(raw: String?): String {
    return normalizeTaskExecutionStatus(raw).wireValue
}

fun isTerminalTaskExecutionStatus(raw: String?): Boolean {
    return TaskExecutionStatus.fromRaw(raw).isTerminal
}

fun isSuccessfulTerminalTaskExecutionStatus(raw: String?): Boolean {
    val status = TaskExecutionStatus.fromRaw(raw)
    return status.isTerminal && status.isSuccessful
}

fun isNetworkTaskExecutionStatus(raw: String?): Boolean {
    return TaskExecutionStatus.fromRaw(raw) == TaskExecutionStatus.NetworkError
}

fun isRecoverableTaskExecutionErrorStatus(raw: String?): Boolean {
    return when (TaskExecutionStatus.fromRaw(raw)) {
        TaskExecutionStatus.NetworkError,
        TaskExecutionStatus.ExecutionError -> true
        else -> false
    }
}

internal fun taskStateToken(raw: String?): String {
    return raw?.trim()?.uppercase(Locale.ROOT).orEmpty()
}
