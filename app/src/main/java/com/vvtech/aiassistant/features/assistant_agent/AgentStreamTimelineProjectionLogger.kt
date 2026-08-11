package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal object AgentStreamTimelineProjectionLogger {
    fun log(decision: AgentStreamTimelineProjectionDecision) {
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = "TIMELINE_UI_PROJECTION",
                sessionId = decision.projectionSessionId,
                result = decision.result.name,
                reason = decision.result.reason,
                attributes = buildMap {
                    put("ledgerHeadSequence", decision.ledgerHeadSequence.toString())
                    decision.previouslyAppliedHeadSequence?.let {
                        put("previouslyAppliedHeadSequence", it.toString())
                    }
                    if (decision.activeStepIndices.isNotEmpty()) {
                        put("activeStepIndices", decision.activeStepIndices.sorted().joinToString(","))
                    }
                },
            )
        )
    }

    private val AgentStreamTimelineProjectionResult.reason: String
        get() = when (this) {
            AgentStreamTimelineProjectionResult.Applied -> "projection_applied"
            AgentStreamTimelineProjectionResult.Deferred -> "active_stream_owner"
            AgentStreamTimelineProjectionResult.IgnoredOlderDeferred ->
                "newer_deferred_projection_retained"
            AgentStreamTimelineProjectionResult.IgnoredStale ->
                "older_than_applied_projection"
            AgentStreamTimelineProjectionResult.IgnoredSessionMismatch -> "session_mismatch"
            AgentStreamTimelineProjectionResult.IgnoredMissingSession -> "missing_current_session"
        }
}
