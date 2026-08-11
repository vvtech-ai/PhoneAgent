package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent

/**
 * Keeps each active live stream as the owner of its step until that exact stream is closed.
 * Historical UI flags are deliberately ignored so an orphaned transient step cannot block
 * durable projections for the rest of the session.
 */
internal class AgentStreamTimelineProjectionGate(
    private val currentSessionId: () -> String?,
    private val applyProjection: (TimelineSnapshotUiProjection) -> Unit,
    private val onDecision: (AgentStreamTimelineProjectionDecision) -> Unit = {},
) {
    private val deferred = mutableMapOf<String, TimelineSnapshotUiProjection>()
    private val activeStepIndices = mutableMapOf<String, MutableSet<Int>>()
    private val appliedHeadSequence = mutableMapOf<String, Long>()

    fun onStreamStarted(stepIndex: Int) {
        discardStaleSessions()
        val sessionId = currentSessionId().normalizedSessionId() ?: return
        activeStepIndices.getOrPut(sessionId, ::linkedSetOf) += stepIndex
    }

    fun onProjectionReady(
        projection: TimelineSnapshotUiProjection
    ): AgentStreamTimelineProjectionDecision {
        discardStaleSessions()
        val sessionId = currentSessionId().normalizedSessionId()
            ?: return decide(
                AgentStreamTimelineProjectionDecision(
                    result = AgentStreamTimelineProjectionResult.IgnoredMissingSession,
                    projectionSessionId = projection.sessionId,
                    ledgerHeadSequence = projection.ledgerHeadSequence,
                )
            )
        if (projection.sessionId != sessionId) {
            return decide(
                AgentStreamTimelineProjectionDecision(
                    result = AgentStreamTimelineProjectionResult.IgnoredSessionMismatch,
                    projectionSessionId = projection.sessionId,
                    ledgerHeadSequence = projection.ledgerHeadSequence,
                )
            )
        }

        if (activeStepIndices[sessionId].orEmpty().isNotEmpty()) {
            val existing = deferred[sessionId]
            if (existing == null || projection.isNewerThan(existing)) {
                deferred[sessionId] = projection
            }
            return decide(
                AgentStreamTimelineProjectionDecision(
                    result = if (existing == null || projection.isNewerThan(existing)) {
                        AgentStreamTimelineProjectionResult.Deferred
                    } else {
                        AgentStreamTimelineProjectionResult.IgnoredOlderDeferred
                    },
                    projectionSessionId = projection.sessionId,
                    ledgerHeadSequence = projection.ledgerHeadSequence,
                    activeStepIndices = activeStepIndices[sessionId].orEmpty().toSet(),
                )
            )
        }

        deferred.remove(sessionId)?.takeIf { it.isNewerThan(projection) }?.let { newer ->
            return apply(sessionId, newer)
        }
        return apply(sessionId, projection)
    }

    fun onStreamTerminal(stepIndex: Int) {
        discardStaleSessions()
        val sessionId = currentSessionId().normalizedSessionId() ?: return
        activeStepIndices[sessionId]?.let { indices ->
            indices -= stepIndex
            if (indices.isEmpty()) {
                activeStepIndices.remove(sessionId)
            }
        }
        if (activeStepIndices[sessionId].orEmpty().isNotEmpty()) return
        deferred.remove(sessionId)?.let { apply(sessionId, it) }
    }

    private fun discardStaleSessions() {
        val sessionId = currentSessionId().normalizedSessionId()
        deferred.keys.removeAll { it != sessionId }
        activeStepIndices.keys.removeAll { it != sessionId }
        appliedHeadSequence.keys.removeAll { it != sessionId }
    }

    private fun apply(
        sessionId: String,
        projection: TimelineSnapshotUiProjection,
    ): AgentStreamTimelineProjectionDecision {
        val previousHead = appliedHeadSequence[sessionId]
        if (previousHead != null && projection.ledgerHeadSequence < previousHead) {
            return decide(
                AgentStreamTimelineProjectionDecision(
                    result = AgentStreamTimelineProjectionResult.IgnoredStale,
                    projectionSessionId = projection.sessionId,
                    ledgerHeadSequence = projection.ledgerHeadSequence,
                    previouslyAppliedHeadSequence = previousHead,
                )
            )
        }
        applyProjection(projection)
        appliedHeadSequence[sessionId] = maxOf(
            previousHead ?: Long.MIN_VALUE,
            projection.ledgerHeadSequence,
        )
        return decide(
            AgentStreamTimelineProjectionDecision(
                result = AgentStreamTimelineProjectionResult.Applied,
                projectionSessionId = projection.sessionId,
                ledgerHeadSequence = projection.ledgerHeadSequence,
                previouslyAppliedHeadSequence = previousHead,
            )
        )
    }

    private fun decide(
        decision: AgentStreamTimelineProjectionDecision
    ): AgentStreamTimelineProjectionDecision = decision.also(onDecision)
}

internal enum class AgentStreamTimelineProjectionResult {
    Applied,
    Deferred,
    IgnoredOlderDeferred,
    IgnoredStale,
    IgnoredSessionMismatch,
    IgnoredMissingSession,
}

internal data class AgentStreamTimelineProjectionDecision(
    val result: AgentStreamTimelineProjectionResult,
    val projectionSessionId: String,
    val ledgerHeadSequence: Long,
    val previouslyAppliedHeadSequence: Long? = null,
    val activeStepIndices: Set<Int> = emptySet(),
)

private fun TimelineSnapshotUiProjection.isNewerThan(
    other: TimelineSnapshotUiProjection
): Boolean = ledgerHeadSequence > other.ledgerHeadSequence ||
    (ledgerHeadSequence == other.ledgerHeadSequence && timelineItems.size > other.timelineItems.size)

internal fun AgentStreamEvent.terminatesStreamingStep(): Boolean =
    this is AgentStreamEvent.Signal ||
        this is AgentStreamEvent.Final ||
        this is AgentStreamEvent.Err ||
        this is AgentStreamEvent.Done

private fun String?.normalizedSessionId(): String? =
    this?.trim()?.takeIf(String::isNotEmpty)
