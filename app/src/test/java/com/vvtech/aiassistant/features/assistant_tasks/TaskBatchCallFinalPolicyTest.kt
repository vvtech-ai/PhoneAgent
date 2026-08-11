package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskBatchCallFinalPolicyTest {
    @Test
    fun buildsFinalDisplayTextWithLegacyCounts() {
        val result = BatchCallResultPayload(
            status = "RUNNING",
            headline = "批量外呼进行中",
            items = listOf(
                batchItem("1", "SUCCESS"),
                batchItem("2", "FAILED"),
                batchItem("3", "USER_CANCELLED"),
                batchItem("4", "CALLING")
            )
        )

        assertEquals(
            "批量外呼进行中：1 路成功，1 路未完成，1 路已取消，1 路执行中",
            TaskBatchCallFinalPolicy.displayText(result, fallbackText = "")
        )

        val completed = result.copy(status = "COMPLETED", items = result.items.dropLast(1))
        assertEquals(
            "批量外呼完成：1 路成功，1 路未完成，1 路已取消",
            TaskBatchCallFinalPolicy.displayText(completed, fallbackText = "")
        )
        assertEquals("后端文本", TaskBatchCallFinalPolicy.displayText(null, fallbackText = "后端文本"))
    }

    @Test
    fun resolvesFinalConversationStatusWithLegacyFallbacks() {
        assertEquals("COMPLETED", TaskBatchCallFinalPolicy.resolvedConversationStatus(null))
        assertEquals(
            "COMPLETED",
            TaskBatchCallFinalPolicy.resolvedConversationStatus(
                BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "完成",
                    items = listOf(batchItem("1", "SUCCESS"))
                )
            )
        )
        assertEquals(
            "INCOMPLETE",
            TaskBatchCallFinalPolicy.resolvedConversationStatus(
                BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "有失败",
                    items = listOf(batchItem("1", "HUNG_UP"))
                )
            )
        )
        assertEquals(
            "INCOMPLETE",
            TaskBatchCallFinalPolicy.resolvedConversationStatus(
                BatchCallResultPayload(status = "PENDING_CONFIRM", headline = "待确认", items = emptyList())
            )
        )
        assertEquals(
            "INCOMPLETE",
            TaskBatchCallFinalPolicy.resolvedConversationStatus(
                BatchCallResultPayload(status = "PARTIAL_FAIL", headline = "有失败", items = emptyList())
            )
        )
    }

    @Test
    fun detectsItemsNeedingUserConfirmation() {
        assertFalse(TaskBatchCallFinalPolicy.needsUserConfirmation(batchItem("1", "SUCCESS")))
        assertTrue(TaskBatchCallFinalPolicy.needsUserConfirmation(batchItem("2", "MISSED_CALL")))
        assertTrue(TaskBatchCallFinalPolicy.needsUserConfirmation(batchItem("3", "USER_CANCELLED")))
        assertTrue(TaskBatchCallFinalPolicy.needsUserConfirmation(batchItem("4", "SUCCESS", abnormal = true)))
    }

    @Test
    fun buildsBatchFinalStepPatchWithFallbackAndClearedStatusEvents() {
        val fallback = BatchCallResultPayload(
            status = "RUNNING",
            headline = "批量外呼进行中",
            items = listOf(batchItem("1", "CALLING"))
        )

        val patch = TaskBatchCallFinalPolicy.buildStepPatch(
            TaskBatchCallFinalStepInput(
                currentText = "旧文本",
                currentBatchCallResult = null,
                currentCallStatusEvents = listOf("正在拨打张三"),
                payloadText = "批量外呼进行中：1 路执行中",
                payloadBatchCallResult = null,
                fallbackBatchCallResult = fallback
            )
        )

        assertEquals("批量外呼进行中：1 路执行中", patch.text)
        assertSame(fallback, patch.batchCallResult)
        assertTrue(patch.callStatusEvents.isEmpty())

        val blankTextPatch = TaskBatchCallFinalPolicy.buildStepPatch(
            TaskBatchCallFinalStepInput(
                currentText = "旧文本",
                currentBatchCallResult = fallback,
                currentCallStatusEvents = listOf("正在拨打张三"),
                payloadText = " ",
                payloadBatchCallResult = null,
                fallbackBatchCallResult = null
            )
        )
        assertEquals("旧文本", blankTextPatch.text)
        assertSame(fallback, blankTextPatch.batchCallResult)
        assertTrue(blankTextPatch.callStatusEvents.isEmpty())
    }

    @Test
    fun agentStreamHandlerDelegatesBatchFinalPolicy() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val responseReducer =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseStepReducer.kt")
                .readText(Charsets.UTF_8)
        val runtimeHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamBatchCallRuntimeHandler.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamBatchCallActiveStateHolder.kt")
                .readText(Charsets.UTF_8)
        val responseStateHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseStateHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(responseReducer.contains("TaskBatchCallFinalPolicy.displayText"))
        assertTrue(handler.contains("batchCallFinalStepPatch = batchCallRuntimeHandler::buildFinalStepPatch"))
        assertTrue(runtimeHandler.contains("activeState.buildFinalStepPatch"))
        assertTrue(holder.contains("TaskBatchCallFinalPolicy.buildStepPatch"))
        assertTrue(holder.contains("TaskBatchCallFinalStepInput"))
        assertTrue(responseStateHandler.contains("TaskBatchCallFinalPolicy.resolvedConversationStatus"))
        assertTrue(responseStateHandler.contains("TaskBatchCallFinalPolicy.statusText"))

        assertFalse(handler.contains("TaskBatchCallFinalPolicy.buildStepPatch"))
        assertFalse(handler.contains("TaskBatchCallFinalPolicy.displayText"))
        assertFalse(handler.contains("TaskBatchCallFinalPolicy.resolvedConversationStatus"))
        assertFalse(handler.contains("TaskBatchCallFinalPolicy.statusText"))
        assertFalse(handler.contains("needsBatchCallUserConfirmation"))
        assertFalse(handler.contains("路成功"))
        assertFalse(handler.contains("路未完成"))
        assertFalse(handler.contains("批量外呼完成："))
        assertFalse(handler.contains("result.items.any { it.needs"))
    }

    private fun sourceFile(path: String): File {
        return listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }

    private fun batchItem(
        itemId: String,
        status: String,
        abnormal: Boolean = false
    ): BatchCallItemResultPayload {
        return BatchCallItemResultPayload(
            itemId = itemId,
            targetName = "目标$itemId",
            phoneNumber = "1380013800$itemId",
            status = status,
            headline = status,
            detail = status,
            attemptCount = 1,
            recalled = false,
            abnormal = abnormal
        )
    }
}
