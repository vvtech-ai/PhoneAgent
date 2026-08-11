package com.vvtech.aiassistant.domain.task

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskStatusContractTest {
    @Test
    fun normalizesKnownTaskStatusAliases() {
        assertEquals(TaskExecutionStatus.Init, TaskExecutionStatus.fromRaw(""))
        assertEquals(TaskExecutionStatus.Active, TaskExecutionStatus.fromRaw("processing"))
        assertEquals(TaskExecutionStatus.Running, TaskExecutionStatus.fromRaw("in_progress"))
        assertEquals(TaskExecutionStatus.Completed, TaskExecutionStatus.fromRaw("done"))
        assertEquals(TaskExecutionStatus.Success, TaskExecutionStatus.fromRaw("succeeded"))
        assertEquals(TaskExecutionStatus.Incomplete, TaskExecutionStatus.fromRaw("partially_completed"))
        assertEquals(TaskExecutionStatus.Cancelled, TaskExecutionStatus.fromRaw("user_canceled"))
        assertEquals(TaskExecutionStatus.NetworkError, TaskExecutionStatus.fromRaw("network_failure"))
    }

    @Test
    fun preservesUnknownRawStatusAsWireValue() {
        val normalized = normalizeTaskExecutionStatus("custom_state")

        assertEquals(TaskExecutionStatus.Unknown, normalized.status)
        assertEquals("CUSTOM_STATE", normalized.wireValue)
        assertEquals("custom_state", normalized.rawValue)
    }

    @Test
    fun identifiesTerminalAndRecoverableStatuses() {
        assertTrue(isTerminalTaskExecutionStatus("COMPLETED"))
        assertTrue(isTerminalTaskExecutionStatus("INCOMPLETE"))
        assertTrue(TaskExecutionStatus.ExecutionError.isTerminal)
        assertFalse(isTerminalTaskExecutionStatus("RUNNING"))
        assertFalse(TaskExecutionStatus.NetworkError.isTerminal)
        assertTrue(TaskExecutionStatus.NetworkError.isRecoverable)
    }

    @Test
    fun separatesSuccessfulTerminalFromFailedTerminalStatuses() {
        assertTrue(isSuccessfulTerminalTaskExecutionStatus("COMPLETED"))
        assertTrue(isSuccessfulTerminalTaskExecutionStatus("done"))
        assertTrue(isSuccessfulTerminalTaskExecutionStatus("succeeded"))
        assertFalse(isSuccessfulTerminalTaskExecutionStatus("FAILED"))
        assertFalse(isSuccessfulTerminalTaskExecutionStatus("INCOMPLETE"))
        assertFalse(isSuccessfulTerminalTaskExecutionStatus("CANCELLED"))
    }

    @Test
    fun identifiesNetworkAndRecoverableErrorStatuses() {
        assertTrue(isNetworkTaskExecutionStatus("NETWORK_ERROR"))
        assertTrue(isNetworkTaskExecutionStatus("network_failure"))
        assertTrue(isRecoverableTaskExecutionErrorStatus("NETWORK_ERROR"))
        assertTrue(isRecoverableTaskExecutionErrorStatus("TOOL_ERROR"))
        assertFalse(isRecoverableTaskExecutionErrorStatus("FAILED"))
        assertFalse(isRecoverableTaskExecutionErrorStatus("custom_state"))
    }
}
