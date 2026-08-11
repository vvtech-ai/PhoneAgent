package com.vvtech.aiassistant.domain.task

enum class TaskReceiptOutcome(val wireValue: String) {
    Success("SUCCESS"),
    Failed("FAILED"),
    Unclear("UNCLEAR"),
    Cancelled("CANCELLED"),
    Running("RUNNING");

    val isTerminal: Boolean
        get() = this != Running

    val needsAttention: Boolean
        get() = this == Failed || this == Unclear || this == Cancelled

    companion object {
        fun fromRaw(raw: String?): TaskReceiptOutcome {
            return when (taskStateToken(raw)) {
                "SUCCESS", "ACCEPTED", "COMPLETED", "CONFIRMED", "DONE", "FINISHED" -> Success
                "FAILED", "FAIL", "ERROR", "DECLINED", "REJECTED", "REFUSED",
                "MISSED", "MISSED_CALL", "NO_ANSWER", "NOANSWER", "TIMEOUT",
                "HUNG_UP", "HANG_UP", "HANGUP" -> Failed
                "USER_CANCELLED", "USER_CANCELED", "CANCELLED", "CANCELED", "USER_INTERRUPTED" -> Cancelled
                "STARTED", "CALLING", "DIALING", "RECALLING", "RETRYING", "REDIALING", "RUNNING" -> Running
                "UNCLEAR", "PENDING", "ABNORMAL", "NEEDS_RECALL", "" -> Unclear
                else -> Unclear
            }
        }
    }
}

data class TaskReceiptItemState(
    val itemId: String,
    val targetName: String,
    val status: String,
    val headline: String = "",
    val detail: String = "",
    val attemptCount: Int = 1,
    val recalled: Boolean = false,
    val abnormal: Boolean = false,
    val transcript: String? = null,
    val receiptFields: List<ReceiptField> = emptyList(),
) {
    val outcome: TaskReceiptOutcome = TaskReceiptOutcome.fromRaw(status)
    val isTerminal: Boolean = outcome.isTerminal
    val needsAttention: Boolean = abnormal || outcome.needsAttention
}

data class BatchTaskReceiptSummary(
    val totalCount: Int,
    val successCount: Int,
    val failedCount: Int,
    val unclearCount: Int,
    val cancelledCount: Int,
    val runningCount: Int
) {
    val isRunning: Boolean
        get() = runningCount > 0

    val allSuccess: Boolean
        get() = totalCount > 0 && successCount == totalCount

    val needsFollowUp: Boolean
        get() = failedCount + unclearCount + cancelledCount > 0
}

data class BatchTaskReceiptState(
    val batchId: String? = null,
    val status: String = TaskReceiptOutcome.Running.wireValue,
    val headline: String = "",
    val items: List<TaskReceiptItemState> = emptyList()
) {
    val summary: BatchTaskReceiptSummary = summarizeTaskReceipts(items)
}

data class TaskReceiptDomainState(
    val taskStatus: TaskExecutionStatus = TaskExecutionStatus.Init,
    val singleReceipt: TaskReceiptItemState? = null,
    val batchReceipt: BatchTaskReceiptState? = null,
    val reason: String? = null
)

sealed class TaskReceiptDomainEvent {
    data class TaskStatusChanged(
        val status: String,
        val reason: String? = null
    ) : TaskReceiptDomainEvent()

    data class SingleReceiptUpdated(
        val receipt: TaskReceiptItemState,
        val reason: String? = null
    ) : TaskReceiptDomainEvent()

    data class BatchSnapshotUpdated(
        val batch: BatchTaskReceiptState,
        val reason: String? = null
    ) : TaskReceiptDomainEvent()

    data class BatchItemProgressUpdated(
        val item: TaskReceiptItemState,
        val batchId: String? = null,
        val headline: String? = null,
        val reason: String? = null
    ) : TaskReceiptDomainEvent()

    data class Cleared(val reason: String? = null) : TaskReceiptDomainEvent()
}

object TaskReceiptStateReducer {
    fun reduce(
        state: TaskReceiptDomainState,
        event: TaskReceiptDomainEvent
    ): TaskReceiptDomainState {
        return when (event) {
            is TaskReceiptDomainEvent.TaskStatusChanged -> state.copy(
                taskStatus = TaskExecutionStatus.fromRaw(event.status),
                reason = event.reason
            )

            is TaskReceiptDomainEvent.SingleReceiptUpdated -> state.copy(
                singleReceipt = event.receipt,
                taskStatus = event.receipt.toTaskExecutionStatus(),
                reason = event.reason
            )

            is TaskReceiptDomainEvent.BatchSnapshotUpdated -> state.copy(
                batchReceipt = event.batch,
                taskStatus = event.batch.toTaskExecutionStatus(),
                reason = event.reason
            )

            is TaskReceiptDomainEvent.BatchItemProgressUpdated -> {
                val currentBatch = state.batchReceipt ?: BatchTaskReceiptState(
                    batchId = event.batchId,
                    headline = event.headline.orEmpty()
                )
                val updatedBatch = currentBatch.copy(
                    batchId = event.batchId ?: currentBatch.batchId,
                    headline = event.headline ?: currentBatch.headline,
                    items = mergeReceiptItem(currentBatch.items, event.item)
                )
                state.copy(
                    batchReceipt = updatedBatch,
                    taskStatus = updatedBatch.toTaskExecutionStatus(),
                    reason = event.reason
                )
            }

            is TaskReceiptDomainEvent.Cleared -> TaskReceiptDomainState(reason = event.reason)
        }
    }

    private fun mergeReceiptItem(
        items: List<TaskReceiptItemState>,
        item: TaskReceiptItemState
    ): List<TaskReceiptItemState> {
        val index = items.indexOfFirst { it.itemId == item.itemId }
        if (index < 0) return items + item
        return items.mapIndexed { itemIndex, existing ->
            if (itemIndex == index) item else existing
        }
    }
}

fun summarizeTaskReceipts(items: List<TaskReceiptItemState>): BatchTaskReceiptSummary {
    var success = 0
    var failed = 0
    var unclear = 0
    var cancelled = 0
    var running = 0
    items.forEach { item ->
        when (item.outcome) {
            TaskReceiptOutcome.Success -> success += 1
            TaskReceiptOutcome.Failed -> failed += 1
            TaskReceiptOutcome.Unclear -> unclear += 1
            TaskReceiptOutcome.Cancelled -> cancelled += 1
            TaskReceiptOutcome.Running -> running += 1
        }
    }
    return BatchTaskReceiptSummary(
        totalCount = items.size,
        successCount = success,
        failedCount = failed,
        unclearCount = unclear,
        cancelledCount = cancelled,
        runningCount = running
    )
}

private fun TaskReceiptItemState.toTaskExecutionStatus(): TaskExecutionStatus {
    return when (outcome) {
        TaskReceiptOutcome.Success -> TaskExecutionStatus.Completed
        TaskReceiptOutcome.Running -> TaskExecutionStatus.Running
        TaskReceiptOutcome.Failed,
        TaskReceiptOutcome.Unclear,
        TaskReceiptOutcome.Cancelled -> TaskExecutionStatus.Incomplete
    }
}

private fun BatchTaskReceiptState.toTaskExecutionStatus(): TaskExecutionStatus {
    return when {
        summary.isRunning -> TaskExecutionStatus.Running
        summary.allSuccess -> TaskExecutionStatus.Completed
        summary.needsFollowUp -> TaskExecutionStatus.Incomplete
        items.isEmpty() -> TaskExecutionStatus.Init
        else -> TaskExecutionStatus.Completed
    }
}
