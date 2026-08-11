package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.FinalTaskStatusKind
import com.vvtech.aiassistant.features.assistant.backendTaskStatusLabel as legacyBackendTaskStatusLabel
import com.vvtech.aiassistant.features.assistant.canonicalConversationTaskStatus as legacyCanonicalConversationTaskStatus
import com.vvtech.aiassistant.features.assistant.conversationStatusLabel as legacyConversationStatusLabel
import com.vvtech.aiassistant.features.assistant.finalTaskStatusDisplayLabel as legacyFinalTaskStatusDisplayLabel
import com.vvtech.aiassistant.features.assistant.finalTaskStatusKind as legacyFinalTaskStatusKind
import com.vvtech.aiassistant.features.assistant.isCompletedConversationStatus as legacyIsCompletedConversationStatus
import com.vvtech.aiassistant.features.assistant.isReadOnlyConversationStatus as legacyIsReadOnlyConversationStatus
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskConversationStatusDisplayPolicyTest {
    @Test
    fun canonicalStatusKeepsLegacySemantics() {
        assertEquals("COMPLETED", canonicalConversationTaskStatus("COMPLETED"))
        assertEquals("COMPLETED", canonicalConversationTaskStatus("任务已完成"))
        assertEquals("INCOMPLETE", canonicalConversationTaskStatus("未完成"))
        assertEquals("FAILED", canonicalConversationTaskStatus("FAILED"))
        assertEquals("CANCELED", canonicalConversationTaskStatus("CANCELLED"))
        assertEquals("RUNNING", canonicalConversationTaskStatus("WAITING_CONFIRM"))
        assertEquals("USER_INTERRUPTED", canonicalConversationTaskStatus("USER_INTERRUPTED"))
        assertEquals("EXECUTION_ERROR", canonicalConversationTaskStatus("NETWORK_ERROR"))
        assertEquals("EXECUTION_ERROR", canonicalConversationTaskStatus("模型服务异常"))
    }

    @Test
    fun displayKindAndLabelsKeepLegacySemantics() {
        assertEquals(TaskConversationStatusKind.Running, taskConversationStatusKind("执行中"))
        assertEquals(TaskConversationStatusKind.Running, taskConversationStatusKind("待确认"))
        assertEquals(TaskConversationStatusKind.Completed, taskConversationStatusKind("COMPLETED"))
        assertEquals(TaskConversationStatusKind.Incomplete, taskConversationStatusKind("UNCLEAR"))
        assertEquals(TaskConversationStatusKind.Incomplete, taskConversationStatusKind("未接电话"))
        assertEquals(TaskConversationStatusKind.ExecutionError, taskConversationStatusKind("SIP_ERROR"))

        assertEquals("进行中", taskStatusDisplayLabel("PENDING"))
        assertEquals("未完成", taskStatusDisplayLabel("FAILED"))
        assertEquals("已完成", taskStatusDisplayLabel("COMPLETED"))
        assertEquals("执行异常", taskStatusDisplayLabel("EXECUTION_ERROR"))

        assertEquals("进行中", conversationStatusLabel("PENDING"))
        assertEquals("未完成", conversationStatusLabel("FAILED"))
        assertEquals("已完成", conversationStatusLabel("COMPLETED"))
        assertEquals("执行异常", conversationStatusLabel("NETWORK_ERROR"))
        assertEquals("进行中", conversationStatusLabel("USER_INTERRUPTED"))
    }

    @Test
    fun readOnlyAndCompletedStatusMatchRestorationRules() {
        assertTrue(isCompletedConversationStatus("COMPLETED"))
        assertFalse(isCompletedConversationStatus("USER_INTERRUPTED"))

        assertFalse(isReadOnlyConversationStatus("COMPLETED"))
        assertFalse(isReadOnlyConversationStatus("CANCELED"))
        assertTrue(isReadOnlyConversationStatus("CLOSED"))
        assertFalse(isReadOnlyConversationStatus("USER_INTERRUPTED"))
        assertFalse(isReadOnlyConversationStatus("FAILED"))
        assertFalse(isReadOnlyConversationStatus("NETWORK_ERROR"))
    }

    @Test
    fun legacyAssistantEntrypointsDelegateToTaskBoundary() {
        assertEquals(canonicalConversationTaskStatus("NETWORK_ERROR"), legacyCanonicalConversationTaskStatus("NETWORK_ERROR"))
        assertEquals(FinalTaskStatusKind.Completed, legacyFinalTaskStatusKind("COMPLETED"))
        assertEquals("进行中", legacyFinalTaskStatusDisplayLabel("READY_TO_EXECUTE"))
        assertEquals("执行异常", legacyConversationStatusLabel("EXECUTION_ERROR"))
        assertEquals("执行异常", legacyBackendTaskStatusLabel("SIP_ERROR"))
        assertTrue(legacyIsCompletedConversationStatus("COMPLETED"))
        assertFalse(legacyIsReadOnlyConversationStatus("USER_INTERRUPTED"))
    }

    @Test
    fun taskBoundaryDoesNotDependOnLegacyAssistantStatusEntrypoints() {
        val taskStatusPolicy =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationStatusPolicy.kt")
                .readText()
        val taskDisplayPolicy =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationStatusDisplayPolicy.kt")
                .readText()
        val restoreMapper =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreSnapshotMapper.kt")
                .readText()

        assertFalse(taskStatusPolicy.contains("features.assistant.canonicalConversationTaskStatus"))
        assertFalse(taskDisplayPolicy.contains("features.assistant."))
        assertFalse(restoreMapper.contains("features.assistant.isReadOnlyConversationStatus"))
        assertTrue(restoreMapper.contains("features.assistant_tasks.isReadOnlyConversationStatus"))
    }
}
