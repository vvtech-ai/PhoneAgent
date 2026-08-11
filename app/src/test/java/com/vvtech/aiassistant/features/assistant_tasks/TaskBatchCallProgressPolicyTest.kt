package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskBatchCallProgressPolicyTest {
    @Test
    fun normalizesLegacyProgressStatusesAndHeadlines() {
        assertEquals("SUCCESS", TaskBatchCallProgressPolicy.normalizeStatus("accepted"))
        assertEquals("任务完成", TaskBatchCallProgressPolicy.headline("SUCCESS"))
        assertFalse(TaskBatchCallProgressPolicy.needsAttention("SUCCESS"))

        assertEquals("FAILED", TaskBatchCallProgressPolicy.normalizeStatus("MISSED_CALL"))
        assertEquals("未完成", TaskBatchCallProgressPolicy.headline("FAILED"))
        assertTrue(TaskBatchCallProgressPolicy.needsAttention("FAILED"))

        assertEquals("RECALLING", TaskBatchCallProgressPolicy.normalizeStatus("redialing"))
        assertEquals("正在重拨", TaskBatchCallProgressPolicy.headline("RECALLING"))
        assertTrue(TaskBatchCallProgressPolicy.isRunning("RECALLING"))
        assertFalse(TaskBatchCallProgressPolicy.isTerminal("RECALLING"))

        assertEquals("UNCLEAR", TaskBatchCallProgressPolicy.normalizeStatus(null))
        assertEquals("任务完成", TaskBatchCallProgressPolicy.headline("UNCLEAR"))
    }

    @Test
    fun buildsProgressItemPreservingExistingValuesAndRecallAttempt() {
        val existing = BatchCallItemResultPayload(
            itemId = "item-1",
            targetName = "张三",
            phoneNumber = "13800138000",
            status = "CALLING",
            headline = "正在拨打",
            detail = "第一次拨打",
            attemptCount = 1,
            recalled = false,
            abnormal = true,
            transcript = "商家已接听"
        )

        val item = TaskBatchCallProgressPolicy.buildItem(
            input = TaskBatchCallProgressInput(
                batchId = "batch-1",
                itemIndex = 2,
                targetName = "",
                phoneNumber = "",
                status = "retrying",
                text = "正在重拨"
            ),
            existing = existing
        )

        assertEquals("item-1", item.itemId)
        assertEquals("张三", item.targetName)
        assertEquals("13800138000", item.phoneNumber)
        assertEquals("RECALLING", item.status)
        assertEquals("正在重拨", item.headline)
        assertEquals("正在重拨", item.detail)
        assertEquals(2, item.attemptCount)
        assertTrue(item.recalled)
        assertTrue(item.abnormal)
        assertEquals("商家已接听", item.transcript)
    }

    @Test
    fun buildsSnapshotWithTerminalCountAndTotalHint() {
        val success = batchItem(itemId = "1", status = "SUCCESS")
        val calling = batchItem(itemId = "2", status = "CALLING")

        val snapshot = TaskBatchCallProgressPolicy.buildSnapshot(
            totalHint = 3,
            items = listOf(success, calling)
        )

        requireNotNull(snapshot)
        assertEquals("RUNNING", snapshot.status)
        assertEquals("批量外呼进行中，1/3 路已有结果", snapshot.headline)
        assertEquals(listOf(success, calling), snapshot.items)
        assertNull(TaskBatchCallProgressPolicy.buildSnapshot(totalHint = 0, items = emptyList()))
    }

    @Test
    fun agentStreamHandlerDelegatesBatchProgressPolicy() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val runtimeHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamBatchCallRuntimeHandler.kt")
                .readText(Charsets.UTF_8)
        val holder =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamBatchCallActiveStateHolder.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamBatchCallRuntimeHandler"))
        assertTrue(runtimeHandler.contains("AgentStreamBatchCallActiveStateHolder"))
        assertTrue(handler.contains("applyProgress = batchCallRuntimeHandler::applyProgress"))
        assertTrue(runtimeHandler.contains("activeState.applyProgress"))
        assertTrue(holder.contains("TaskBatchCallProgressPolicy.buildItem"))
        assertTrue(holder.contains("TaskBatchCallProgressPolicy.buildSnapshot"))
        assertTrue(holder.contains("TaskBatchCallProgressInput"))

        assertFalse(handler.contains("TaskBatchCallProgressPolicy.buildItem"))
        assertFalse(handler.contains("TaskBatchCallProgressPolicy.buildSnapshot"))
        assertFalse(handler.contains("TaskBatchCallProgressInput"))
        assertFalse(handler.contains("normalizeBatchProgressStatus"))
        assertFalse(handler.contains("batchProgressHeadline"))
        assertFalse(handler.contains("batchProgressNeedsAttention"))
        assertFalse(handler.contains("isBatchCallRunningStatus"))
        assertFalse(handler.contains("isBatchCallTerminalStatus"))
    }

    private fun batchItem(
        itemId: String,
        status: String
    ): BatchCallItemResultPayload {
        return BatchCallItemResultPayload(
            itemId = itemId,
            targetName = "目标$itemId",
            phoneNumber = "1380013800$itemId",
            status = status,
            headline = TaskBatchCallProgressPolicy.headline(status),
            detail = TaskBatchCallProgressPolicy.headline(status),
            attemptCount = 1,
            recalled = false,
            abnormal = TaskBatchCallProgressPolicy.needsAttention(status)
        )
    }
}
