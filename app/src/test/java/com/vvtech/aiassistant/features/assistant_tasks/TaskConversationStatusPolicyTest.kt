package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class TaskConversationStatusPolicyTest {
    @Test
    fun explicitDetailTerminalStatusWinsOverRunningListStatus() {
        assertEquals(
            "COMPLETED",
            normalizeConversationTaskStatus(rawStatus = "RUNNING", detailStatus = "COMPLETED"),
        )
    }

    @Test
    fun explicitTechnicalFailureHasPriority() {
        assertEquals(
            "EXECUTION_ERROR",
            normalizeConversationTaskStatus(rawStatus = "COMPLETED", detailStatus = "EXECUTION_ERROR"),
        )
    }

    @Test
    fun pendingStatusRemainsRunningWithoutTextInference() {
        assertEquals("RUNNING", normalizeConversationTaskStatus(rawStatus = "ACTIVE"))
        assertEquals("RUNNING", normalizeConversationTaskStatus(rawStatus = "PENDING"))
    }

    @Test
    fun statusPolicyDoesNotDependOnConversationDetailOrLegacyParser() {
        val source = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationStatusPolicy.kt",
        ).readText()

        assertFalse(source.contains("ConversationDetail"))
        assertFalse(source.contains("withResolvedStatus"))
        assertFalse(source.contains("extractConversationOutcomeText"))
        assertFalse(source.contains("conversationStatusFromBatchCallResult"))
        assertFalse(source.contains("conversationStatusFromReportedCallOutcome"))
    }
}
