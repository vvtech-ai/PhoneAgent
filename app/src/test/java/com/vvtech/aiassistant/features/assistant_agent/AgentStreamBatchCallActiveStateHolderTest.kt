package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamBatchCallActiveStateHolderTest {
    @Test
    fun marksPendingBatchAndKeepsItemsWhenRealBatchIdArrivesForSameStep() {
        val holder = AgentStreamBatchCallActiveStateHolder()

        holder.markStream(stepIndex = 3, batchId = null, total = 2)
        assertTrue(holder.isActive())
        assertTrue(holder.isActiveStep(3))
        assertEquals("pending:3", holder.currentBatchId())

        holder.applyProgress(
            stepIndex = 3,
            event = progressEvent(batchId = null, itemIndex = 1, targetName = "张三", status = "CALLING"),
            text = "正在拨打张三"
        )
        val update = holder.applyProgress(
            stepIndex = 3,
            event = progressEvent(batchId = "batch-1", itemIndex = 2, targetName = "李四", status = "SUCCESS"),
            text = "李四已确认"
        )
        val snapshot = update.snapshot

        requireNotNull(snapshot)
        assertTrue(update.handled)
        assertEquals("batch-1", holder.currentBatchId())
        assertEquals("batch-1", snapshot.batchId)
        assertEquals(2, snapshot.items.size)
        assertEquals(listOf("张三", "李四"), snapshot.items.map { it.targetName })
        assertEquals("批量外呼进行中，1/2 路已有结果", snapshot.headline)
    }

    @Test
    fun resetsItemsWhenStepOrRealBatchIdChanges() {
        val holder = AgentStreamBatchCallActiveStateHolder()

        holder.applyProgress(
            stepIndex = 1,
            event = progressEvent(batchId = "batch-a", itemIndex = 1, targetName = "张三", status = "SUCCESS"),
            text = "张三已确认"
        )
        val nextStepUpdate = holder.applyProgress(
            stepIndex = 2,
            event = progressEvent(batchId = "batch-a", itemIndex = 2, targetName = "李四", status = "FAILED"),
            text = "李四未接听"
        )
        val nextStepSnapshot = nextStepUpdate.snapshot

        requireNotNull(nextStepSnapshot)
        assertEquals(listOf("李四"), nextStepSnapshot.items.map { it.targetName })

        val nextBatchUpdate = holder.applyProgress(
            stepIndex = 2,
            event = progressEvent(batchId = "batch-b", itemIndex = 1, targetName = "王五", status = "CALLING"),
            text = "正在拨打王五"
        )
        val nextBatchSnapshot = nextBatchUpdate.snapshot

        requireNotNull(nextBatchSnapshot)
        assertEquals("batch-b", holder.currentBatchId())
        assertEquals(listOf("王五"), nextBatchSnapshot.items.map { it.targetName })
    }

    @Test
    fun buildsFinalPatchUsingSnapshotFallbackAndClearsState() {
        val holder = AgentStreamBatchCallActiveStateHolder()
        holder.applyProgress(
            stepIndex = 1,
            event = progressEvent(batchId = "batch-a", itemIndex = 1, targetName = "张三", status = "CALLING"),
            text = "正在拨打张三"
        )

        val patch = holder.buildFinalStepPatch(
            currentText = "",
            currentBatchCallResult = null,
            currentCallStatusEvents = listOf("正在拨打张三"),
            payloadText = "批量外呼进行中：1 路执行中",
            payloadBatchCallResult = null
        )

        assertEquals("批量外呼进行中：1 路执行中", patch.text)
        requireNotNull(patch.batchCallResult)
        assertEquals("RUNNING", patch.batchCallResult.status)
        assertEquals(listOf("张三"), patch.batchCallResult.items.map { it.targetName })
        assertTrue(patch.callStatusEvents.isEmpty())

        assertTrue(holder.clear())
        assertFalse(holder.isActive())
        assertNull(holder.snapshot())
    }

    @Test
    fun keepsExistingOrPayloadBatchResultAheadOfSnapshotFallback() {
        val holder = AgentStreamBatchCallActiveStateHolder()
        holder.applyProgress(
            stepIndex = 1,
            event = progressEvent(batchId = "batch-a", itemIndex = 1, targetName = "张三", status = "CALLING"),
            text = "正在拨打张三"
        )
        val current = BatchCallResultPayload(status = "CURRENT", headline = "当前结果", items = emptyList())
        val payload = BatchCallResultPayload(status = "PAYLOAD", headline = "后端结果", items = emptyList())

        val currentPatch = holder.buildFinalStepPatch(
            currentText = "旧文本",
            currentBatchCallResult = current,
            currentCallStatusEvents = emptyList(),
            payloadText = "",
            payloadBatchCallResult = null
        )
        assertSame(current, currentPatch.batchCallResult)

        val payloadPatch = holder.buildFinalStepPatch(
            currentText = "旧文本",
            currentBatchCallResult = current,
            currentCallStatusEvents = emptyList(),
            payloadText = "",
            payloadBatchCallResult = payload
        )
        assertSame(payload, payloadPatch.batchCallResult)
    }

    @Test
    fun ignoresNonBatchStatusDelta() {
        val holder = AgentStreamBatchCallActiveStateHolder()

        val update = holder.applyProgress(
            stepIndex = 1,
            event = AgentStreamEvent.StatusDelta(text = "普通状态"),
            text = "普通状态"
        )

        assertFalse(update.handled)
        assertNull(update.snapshot)
        assertFalse(holder.isActive())
        assertFalse(holder.clear())
    }

    @Test
    fun handlesBatchProgressWithoutSnapshot() {
        val holder = AgentStreamBatchCallActiveStateHolder()

        val update = holder.applyProgress(
            stepIndex = 1,
            event = AgentStreamEvent.StatusDelta(text = "批量外呼开始", progressOnly = true),
            text = "批量外呼开始"
        )

        assertTrue(update.handled)
        assertNull(update.snapshot)
        assertTrue(holder.isActive())
        assertEquals("pending:1", holder.currentBatchId())
    }

    @Test
    fun agentStreamHandlerDelegatesBatchActiveStateHolder() {
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val runtimeHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamBatchCallRuntimeHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamBatchCallRuntimeHandler"))
        assertTrue(runtimeHandler.contains("AgentStreamBatchCallActiveStateHolder"))
        assertFalse(handler.contains("private var activeBatchCallId"))
        assertFalse(handler.contains("private var activeBatchCallStepIndex"))
        assertFalse(handler.contains("private var activeBatchCallTotal"))
        assertFalse(handler.contains("activeBatchCallItems"))
        assertFalse(handler.contains("AgentStreamBatchCallActiveStateHolder()"))
        assertFalse(handler.contains("activeBatchCallState."))
    }

    private fun progressEvent(
        batchId: String?,
        itemIndex: Int,
        targetName: String,
        status: String
    ): AgentStreamEvent.StatusDelta {
        return AgentStreamEvent.StatusDelta(
            text = status,
            batchId = batchId,
            itemIndex = itemIndex,
            total = 2,
            targetName = targetName,
            phoneNumber = "1380013800$itemIndex",
            batchStatus = status,
            progressOnly = true
        )
    }
}
