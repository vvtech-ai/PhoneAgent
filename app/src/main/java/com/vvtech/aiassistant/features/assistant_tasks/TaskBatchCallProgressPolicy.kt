package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload

internal data class TaskBatchCallProgressInput(
    val batchId: String?,
    val itemIndex: Int,
    val targetName: String,
    val phoneNumber: String,
    val status: String?,
    val text: String
)

internal object TaskBatchCallProgressPolicy {

    fun buildItem(
        input: TaskBatchCallProgressInput,
        existing: BatchCallItemResultPayload?
    ): BatchCallItemResultPayload {
        val status = normalizeStatus(input.status)
        val recalled = existing?.recalled == true ||
            status == "RECALLING" ||
            input.text.contains("重拨") ||
            input.text.contains("回拨")
        return BatchCallItemResultPayload(
            itemId = existing?.itemId ?: "progress_${input.batchId.orEmpty()}_${input.itemIndex}",
            targetName = input.targetName.ifBlank { existing?.targetName.orEmpty() },
            phoneNumber = input.phoneNumber.ifBlank { existing?.phoneNumber.orEmpty() },
            status = status,
            headline = headline(status),
            detail = input.text.ifBlank { headline(status) },
            attemptCount = maxOf(existing?.attemptCount ?: 1, if (recalled) 2 else 1),
            recalled = recalled,
            abnormal = needsAttention(status),
            transcript = existing?.transcript
        )
    }

    fun buildSnapshot(
        totalHint: Int,
        items: List<BatchCallItemResultPayload>,
        batchId: String? = null,
    ): BatchCallResultPayload? {
        if (items.isEmpty()) return null
        val total = maxOf(totalHint, items.size)
        val finished = items.count { isTerminal(it.status) }
        return BatchCallResultPayload(
            status = "RUNNING",
            headline = "批量外呼进行中，$finished/$total 路已有结果",
            items = items,
            batchId = batchId,
        )
    }

    fun normalizeStatus(raw: String?): String {
        return when (raw?.trim()?.uppercase().orEmpty()) {
            "SUCCESS", "ACCEPTED", "CONFIRMED" -> "SUCCESS"
            "FAILED", "FAIL", "ERROR" -> "FAILED"
            "UNCLEAR" -> "UNCLEAR"
            "USER_CANCELLED", "USER_CANCELED", "CANCELLED", "CANCELED" -> "USER_CANCELLED"
            "NEEDS_RECALL" -> "NEEDS_RECALL"
            "DECLINED", "REJECTED", "REFUSED" -> "FAILED"
            "MISSED", "MISSED_CALL", "NO_ANSWER", "NOANSWER", "TIMEOUT" -> "FAILED"
            "HUNG_UP", "HANG_UP", "HANGUP" -> "FAILED"
            "ABNORMAL", "PENDING" -> "UNCLEAR"
            "RECALLING", "RETRYING", "REDIALING" -> "RECALLING"
            "CALLING", "DIALING" -> "CALLING"
            "STARTED" -> "STARTED"
            "" -> "UNCLEAR"
            else -> raw?.trim()?.uppercase().orEmpty()
        }
    }

    fun headline(status: String): String {
        return when (status.trim().uppercase()) {
            "SUCCESS" -> "任务完成"
            "FAILED" -> "未完成"
            "UNCLEAR" -> "任务完成"
            "USER_CANCELLED", "USER_CANCELED", "CANCELLED", "CANCELED" -> "已取消"
            "NEEDS_RECALL" -> "需重拨"
            "RECALLING" -> "正在重拨"
            "CALLING" -> "正在拨打"
            "STARTED" -> "正在拨打"
            else -> "任务完成"
        }
    }

    fun needsAttention(status: String): Boolean {
        val normalized = status.trim().uppercase()
        return normalized == "FAILED" ||
            normalized == "USER_CANCELLED" ||
            normalized == "USER_CANCELED" ||
            normalized == "CANCELLED" ||
            normalized == "CANCELED" ||
            normalized == "DECLINED" ||
            normalized == "MISSED_CALL" ||
            normalized == "HUNG_UP" ||
            isRunning(status)
    }

    fun isRunning(status: String): Boolean {
        return status.equals("STARTED", ignoreCase = true) ||
            status.equals("CALLING", ignoreCase = true) ||
            status.equals("RECALLING", ignoreCase = true) ||
            status.equals("RUNNING", ignoreCase = true)
    }

    fun isTerminal(status: String): Boolean = !isRunning(status)
}
