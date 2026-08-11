package com.vvtech.aiassistant.domain.task

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskReceiptContractTest {
    @Test
    fun mapsReceiptStatusToStableOutcome() {
        assertEquals(TaskReceiptOutcome.Success, TaskReceiptOutcome.fromRaw("ACCEPTED"))
        assertEquals(TaskReceiptOutcome.Failed, TaskReceiptOutcome.fromRaw("MISSED_CALL"))
        assertEquals(TaskReceiptOutcome.Cancelled, TaskReceiptOutcome.fromRaw("USER_CANCELED"))
        assertEquals(TaskReceiptOutcome.Running, TaskReceiptOutcome.fromRaw("RECALLING"))
        assertEquals(TaskReceiptOutcome.Unclear, TaskReceiptOutcome.fromRaw("NEEDS_RECALL"))
        assertEquals(TaskReceiptOutcome.Unclear, TaskReceiptOutcome.fromRaw("PENDING"))
    }

    @Test
    fun derivesItemAttentionAndTerminalState() {
        val running = receiptItem("1", "CALLING")
        val needsRecall = receiptItem("2", "NEEDS_RECALL")
        val abnormalSuccess = receiptItem("3", "SUCCESS", abnormal = true)

        assertFalse(running.isTerminal)
        assertFalse(running.needsAttention)
        assertTrue(needsRecall.isTerminal)
        assertTrue(needsRecall.needsAttention)
        assertTrue(abnormalSuccess.needsAttention)
    }

    @Test
    fun summarizesBatchReceiptCounts() {
        val summary = summarizeTaskReceipts(
            listOf(
                receiptItem("1", "SUCCESS"),
                receiptItem("2", "FAILED"),
                receiptItem("3", "NEEDS_RECALL"),
                receiptItem("4", "USER_CANCELLED"),
                receiptItem("5", "RECALLING")
            )
        )

        assertEquals(5, summary.totalCount)
        assertEquals(1, summary.successCount)
        assertEquals(1, summary.failedCount)
        assertEquals(1, summary.unclearCount)
        assertEquals(1, summary.cancelledCount)
        assertEquals(1, summary.runningCount)
        assertTrue(summary.isRunning)
        assertFalse(summary.allSuccess)
        assertTrue(summary.needsFollowUp)
    }

    @Test
    fun reducerMergesBatchProgressByItemIdAndPreservesOrder() {
        val initial = TaskReceiptStateReducer.reduce(
            TaskReceiptDomainState(),
            TaskReceiptDomainEvent.BatchSnapshotUpdated(
                batch = BatchTaskReceiptState(
                    batchId = "batch-1",
                    items = listOf(
                        receiptItem("1", "CALLING", targetName = "A"),
                        receiptItem("2", "CALLING", targetName = "B")
                    )
                ),
                reason = "snapshot"
            )
        )

        val updated = TaskReceiptStateReducer.reduce(
            initial,
            TaskReceiptDomainEvent.BatchItemProgressUpdated(
                item = receiptItem("1", "SUCCESS", targetName = "A"),
                reason = "item_success"
            )
        )

        val batch = requireNotNull(updated.batchReceipt)
        assertEquals(listOf("1", "2"), batch.items.map { it.itemId })
        assertEquals(TaskReceiptOutcome.Success, batch.items[0].outcome)
        assertEquals(TaskReceiptOutcome.Running, batch.items[1].outcome)
        assertEquals(TaskExecutionStatus.Running, updated.taskStatus)
        assertEquals("item_success", updated.reason)
    }

    @Test
    fun reducerMarksCompletedBatchAsIncompleteWhenAnyItemNeedsFollowUp() {
        val updated = TaskReceiptStateReducer.reduce(
            TaskReceiptDomainState(),
            TaskReceiptDomainEvent.BatchSnapshotUpdated(
                batch = BatchTaskReceiptState(
                    batchId = "batch-2",
                    items = listOf(
                        receiptItem("1", "SUCCESS"),
                        receiptItem("2", "NEEDS_RECALL")
                    )
                ),
                reason = "final_snapshot"
            )
        )

        val batch = requireNotNull(updated.batchReceipt)
        assertFalse(batch.summary.isRunning)
        assertTrue(batch.summary.needsFollowUp)
        assertEquals(TaskExecutionStatus.Incomplete, updated.taskStatus)
    }

    private fun receiptItem(
        itemId: String,
        status: String,
        targetName: String = itemId,
        abnormal: Boolean = false
    ): TaskReceiptItemState {
        return TaskReceiptItemState(
            itemId = itemId,
            targetName = targetName,
            status = status,
            abnormal = abnormal
        )
    }
}
