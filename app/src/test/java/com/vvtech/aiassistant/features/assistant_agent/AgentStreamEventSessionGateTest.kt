package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamEventSessionGateTest {
    @Test
    fun matchingActiveSessionAcceptsStreamEvent() {
        val harness = Harness(currentSessionId = "session-1")

        val accepted = harness.gate.shouldApply(
            streamSessionId = "session-1",
            event = AgentStreamEvent.TextDelta("处理中"),
        )

        assertTrue(accepted)
        assertEquals(0, harness.clearBatchCalls)
    }

    @Test
    fun closedSessionRejectsProgressAndTerminalResultWithoutKeepingBatchRuntime() {
        val harness = Harness(currentSessionId = null, batchActive = true)

        val progressAccepted = harness.gate.shouldApply(
            streamSessionId = "closed-session",
            event = AgentStreamEvent.StatusDelta(
                text = "正在等待通话结果",
                batchId = "batch-1",
            ),
        )
        val resultAccepted = harness.gate.shouldApply(
            streamSessionId = "closed-session",
            event = AgentStreamEvent.Final(
                AgentChatResponse(
                    sessionId = "closed-session",
                    type = "BATCH_CALL_RESULT",
                    text = null,
                    batchCallResult = BatchCallResultPayload(
                        status = "FAILED",
                        headline = "任务失败",
                        items = emptyList(),
                        batchId = "batch-1",
                    ),
                )
            ),
        )

        assertFalse(progressAccepted)
        assertFalse(resultAccepted)
        assertEquals(1, harness.clearBatchCalls)
    }

    @Test
    fun switchedSessionRejectsPreviousSessionResult() {
        val harness = Harness(currentSessionId = "new-session")

        val accepted = harness.gate.shouldApply(
            streamSessionId = "closed-session",
            event = AgentStreamEvent.Final(
                AgentChatResponse(
                    sessionId = "closed-session",
                    type = "CALL_RESULT",
                    text = null,
                )
            ),
        )

        assertFalse(accepted)
    }

    private class Harness(
        currentSessionId: String?,
        batchActive: Boolean = false,
    ) {
        private var activeSessionId = currentSessionId
        private var activeBatch = batchActive
        var clearBatchCalls = 0
            private set

        val gate = AgentStreamEventSessionGate(
            AgentStreamEventSessionGateCallbacks(
                currentSessionId = { activeSessionId },
                currentState = { Index9AssistantUiState() },
                hasActiveBatchCallStream = { activeBatch },
                clearActiveBatchCallState = {
                    activeBatch = false
                    clearBatchCalls += 1
                },
            )
        )
    }
}
