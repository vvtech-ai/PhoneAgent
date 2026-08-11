package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload

internal data class TaskBatchCallFinalStepInput(
    val currentText: String,
    val currentBatchCallResult: BatchCallResultPayload?,
    val currentCallStatusEvents: List<String>,
    val payloadText: String,
    val payloadBatchCallResult: BatchCallResultPayload?,
    val fallbackBatchCallResult: BatchCallResultPayload?
)

internal data class TaskBatchCallFinalStepPatch(
    val text: String,
    val batchCallResult: BatchCallResultPayload?,
    val callStatusEvents: List<String>
)

internal object TaskBatchCallFinalPolicy {

    fun displayText(
        result: BatchCallResultPayload?,
        fallbackText: String
    ): String {
        result ?: return fallbackText
        val counts = result.items.fold(BatchCallFinalCounts()) { acc, item ->
            when (item.status.trim().uppercase()) {
                "FAILED", "DECLINED", "MISSED_CALL", "HUNG_UP" -> acc.copy(failed = acc.failed + 1)
                "USER_CANCELLED", "USER_CANCELED", "CANCELLED", "CANCELED" -> {
                    acc.copy(cancelled = acc.cancelled + 1)
                }
                "STARTED", "CALLING", "RECALLING", "RUNNING" -> acc.copy(running = acc.running + 1)
                else -> acc.copy(success = acc.success + 1)
            }
        }
        val parts = buildList {
            if (counts.success > 0) add("${counts.success} 路成功")
            if (counts.failed > 0) add("${counts.failed} 路未完成")
            if (counts.cancelled > 0) add("${counts.cancelled} 路已取消")
            if (counts.running > 0) add("${counts.running} 路执行中")
        }
        if (parts.isEmpty()) return result.headline
        val prefix = if (counts.running > 0 || result.status.equals("RUNNING", ignoreCase = true)) {
            "批量外呼进行中"
        } else {
            "批量外呼完成"
        }
        return "$prefix：${parts.joinToString("，")}"
    }

    fun resolvedConversationStatus(result: BatchCallResultPayload?): String {
        return when {
            result == null -> "COMPLETED"
            result.items.any { it.requiresUserConfirmation() } -> "INCOMPLETE"
            result.status.contains("PENDING", ignoreCase = true) -> "INCOMPLETE"
            result.status.contains("FAIL", ignoreCase = true) -> "INCOMPLETE"
            else -> "COMPLETED"
        }
    }

    fun statusText(
        result: BatchCallResultPayload?,
        resolvedConversationStatus: String
    ): String {
        return if (resolvedConversationStatus == "COMPLETED") {
            "任务已完成"
        } else {
            result?.headline ?: "批量外呼已完成"
        }
    }

    fun buildStepPatch(input: TaskBatchCallFinalStepInput): TaskBatchCallFinalStepPatch {
        return TaskBatchCallFinalStepPatch(
            text = mergedBatchText(input.currentText, input.payloadText),
            batchCallResult = input.payloadBatchCallResult
                ?: input.currentBatchCallResult
                ?: input.fallbackBatchCallResult,
            callStatusEvents = emptyList()
        )
    }

    fun needsUserConfirmation(item: BatchCallItemResultPayload): Boolean = item.requiresUserConfirmation()

    private fun mergedBatchText(current: String, payloadText: String): String {
        val text = payloadText.trim()
        if (text.isBlank()) return current
        return text
    }

    private fun BatchCallItemResultPayload.requiresUserConfirmation(): Boolean {
        if (abnormal) return true
        val normalized = status.trim().uppercase()
        return normalized == "FAILED" ||
            normalized == "USER_CANCELLED" ||
            normalized == "USER_CANCELED" ||
            normalized == "CANCELLED" ||
            normalized == "CANCELED" ||
            normalized == "DECLINED" ||
            normalized == "MISSED_CALL" ||
            normalized == "HUNG_UP"
    }
}

private data class BatchCallFinalCounts(
    val success: Int = 0,
    val failed: Int = 0,
    val cancelled: Int = 0,
    val running: Int = 0
)
