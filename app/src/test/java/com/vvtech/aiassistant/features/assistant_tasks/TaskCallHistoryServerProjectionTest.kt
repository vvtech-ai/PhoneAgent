package com.vvtech.aiassistant.features.assistant_tasks

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallHistoryServerProjectionTest {
    @Test
    fun activeCallStatesAreNotHistoryRecords() {
        assertFalse(isTerminalAssistantCallHistoryState("DIALING"))
        assertFalse(isTerminalAssistantCallHistoryState("RINGING"))
        assertFalse(isTerminalAssistantCallHistoryState("CONNECTED"))
    }

    @Test
    fun physicalTerminalStatesAreHistoryRecords() {
        assertTrue(isTerminalAssistantCallHistoryState("COMPLETED"))
        assertTrue(isTerminalAssistantCallHistoryState("ENDED"))
        assertTrue(isTerminalAssistantCallHistoryState("FAILED"))
        assertTrue(isTerminalAssistantCallHistoryState("CANCELLED"))
        assertTrue(isTerminalAssistantCallHistoryState("REJECTED"))
        assertTrue(isTerminalAssistantCallHistoryState("NOT_FOUND"))
    }
}
