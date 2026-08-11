package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AgentStreamTimelineProjectionGateTest {
    @Test
    fun projectionBeforeFinalWaitsThenReconcilesToolAndReplyOnce() {
        val tool = ToolCallInfo(name = "search", args = "", result = "done")
        var state = Index9AssistantUiState(
            clarificationSteps = listOf(
                step(VoiceRole.User, "find one"),
                step(VoiceRole.Assistant, "working"),
                step(
                    role = VoiceRole.Assistant,
                    text = "",
                    toolCalls = listOf(tool),
                    streaming = true,
                ),
            ),
        )
        var applyCount = 0
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { SESSION_ID },
            applyProjection = { projection ->
                applyCount += 1
                state = projection.reduce(state)
            },
        )

        gate.onStreamStarted(STEP_INDEX)
        gate.onProjectionReady(projection("found it"))

        assertEquals(0, applyCount)
        assertEquals("", state.clarificationSteps[STEP_INDEX].text)

        state = state.copy(
            clarificationSteps = state.clarificationSteps.toMutableList().apply {
                this[STEP_INDEX] = this[STEP_INDEX].copy(
                    text = "found it",
                    streaming = false,
                )
            },
        )
        gate.onStreamTerminal(STEP_INDEX)

        val replies = state.clarificationSteps.filter {
            it.role == VoiceRole.Assistant && it.text == "found it"
        }
        assertEquals(1, applyCount)
        assertEquals(1, replies.size)
        assertEquals(listOf(tool), replies.single().toolCalls)
    }

    @Test
    fun sessionProjectionWaitsUntilEveryOwnedStreamIsTerminal() {
        var applyCount = 0
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { SESSION_ID },
            applyProjection = { applyCount += 1 },
        )

        gate.onStreamStarted(1)
        gate.onStreamStarted(2)
        gate.onProjectionReady(projection("found it"))
        gate.onStreamTerminal(1)

        assertEquals(0, applyCount)

        gate.onStreamTerminal(2)

        assertEquals(1, applyCount)
    }

    @Test
    fun historicalStreamingFlagCannotBlockProjectionWithoutAnActiveOwner() {
        var state = Index9AssistantUiState(
            clarificationSteps = listOf(
                step(VoiceRole.Assistant, "", streaming = true),
            ),
        )
        var applyCount = 0
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { SESSION_ID },
            applyProjection = {
                applyCount += 1
                state = it.reduce(
                    state.copy(
                        clarificationSteps = state.clarificationSteps.map { stale ->
                            stale.copy(streaming = false)
                        }
                    )
                )
            },
        )

        gate.onProjectionReady(projection("durable reply"))

        assertEquals(1, applyCount)
        assertFalse(state.clarificationSteps.any { it.streaming })
        assertEquals("durable reply", state.clarificationSteps.last().text)
    }

    @Test
    fun identicalRepliesFromDifferentTurnsRemainSeparate() {
        val tool = ToolCallInfo(name = "search", args = "", result = "done")
        val currentReply = step(
            role = VoiceRole.Assistant,
            text = "found it",
            toolCalls = listOf(tool),
        )
        var state = Index9AssistantUiState(
            clarificationSteps = listOf(
                step(VoiceRole.User, "first search"),
                step(VoiceRole.Assistant, "found it"),
                step(VoiceRole.User, "second search"),
                currentReply,
            ),
        )
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { SESSION_ID },
            applyProjection = { state = it.reduce(state) },
        )
        val projection = projection(
            reply = "found it",
            steps = listOf(
                step(VoiceRole.User, "first search"),
                step(VoiceRole.Assistant, "found it"),
                step(VoiceRole.User, "second search"),
                step(VoiceRole.Assistant, "found it"),
            ),
        )

        gate.onProjectionReady(projection)

        val replies = state.clarificationSteps.filter {
            it.role == VoiceRole.Assistant && it.text == "found it"
        }
        assertEquals(2, replies.size)
        assertEquals(currentReply, replies.last())
    }

    @Test
    fun staleSessionProjectionNeverAppliesToTheCurrentSession() {
        var currentSessionId = "session-b"
        var applyCount = 0
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { currentSessionId },
            applyProjection = { applyCount += 1 },
        )

        gate.onProjectionReady(projection(reply = "old", sessionId = "session-a"))

        assertEquals(0, applyCount)

        currentSessionId = "session-a"
        gate.onProjectionReady(projection(reply = "current", sessionId = "session-a"))

        assertEquals(1, applyCount)
    }

    @Test
    fun newerDeferredProjectionCannotBeReplacedByAnOlderCompletion() {
        val appliedHeads = mutableListOf<Long>()
        val decisions = mutableListOf<AgentStreamTimelineProjectionResult>()
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { SESSION_ID },
            applyProjection = { appliedHeads += it.ledgerHeadSequence },
            onDecision = { decisions += it.result },
        )

        gate.onStreamStarted(STEP_INDEX)
        gate.onProjectionReady(projection("new", ledgerHeadSequence = 22))
        gate.onProjectionReady(projection("old", ledgerHeadSequence = 20))
        gate.onStreamTerminal(STEP_INDEX)

        assertEquals(listOf(22L), appliedHeads)
        assertEquals(
            listOf(
                AgentStreamTimelineProjectionResult.Deferred,
                AgentStreamTimelineProjectionResult.IgnoredOlderDeferred,
                AgentStreamTimelineProjectionResult.Applied,
            ),
            decisions,
        )
    }

    @Test
    fun alreadyAppliedHeadCannotRollBackToAnOlderSnapshot() {
        val appliedHeads = mutableListOf<Long>()
        val gate = AgentStreamTimelineProjectionGate(
            currentSessionId = { SESSION_ID },
            applyProjection = { appliedHeads += it.ledgerHeadSequence },
        )

        val current = gate.onProjectionReady(projection("current", ledgerHeadSequence = 22))
        val stale = gate.onProjectionReady(projection("stale", ledgerHeadSequence = 20))

        assertEquals(AgentStreamTimelineProjectionResult.Applied, current.result)
        assertEquals(AgentStreamTimelineProjectionResult.IgnoredStale, stale.result)
        assertEquals(listOf(22L), appliedHeads)
    }

    private fun projection(
        reply: String,
        sessionId: String = SESSION_ID,
        ledgerHeadSequence: Long = 0L,
        steps: List<ClarificationStep> = listOf(
            step(VoiceRole.User, "find one"),
            step(VoiceRole.Assistant, reply),
        ),
    ) = TimelineSnapshotUiProjection(
        sessionId = sessionId,
        timelineItems = emptyList(),
        clarificationSteps = steps,
        conversationStatus = "COMPLETED",
        conversationContinuable = true,
        pendingToolRestorable = false,
        latestSingleReceipt = null,
        ledgerHeadSequence = ledgerHeadSequence,
    )

    private fun step(
        role: VoiceRole,
        text: String,
        toolCalls: List<ToolCallInfo>? = null,
        streaming: Boolean = false,
    ) = ClarificationStep(
        role = role,
        text = text,
        status = "",
        toolCalls = toolCalls,
        streaming = streaming,
    )

    private companion object {
        const val SESSION_ID = "session-1"
        const val STEP_INDEX = 2
    }
}
