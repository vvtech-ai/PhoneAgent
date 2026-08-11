package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.domain.realtime.RealtimeLifecycleState
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeDomain
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeEvent
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeState
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeStateReducer
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal class VoiceRuntimeEventRecorder {
    private var runtimeState = RealtimeRuntimeState(domain = RealtimeRuntimeDomain.Voice)

    fun reset() {
        runtimeState = RealtimeRuntimeState(domain = RealtimeRuntimeDomain.Voice)
    }

    fun record(transition: TaskVoiceTurnTransition, taskId: String?) {
        val event = VoiceRuntimeEventPolicy.transitionEvent(transition, taskId)
        runtimeState = RealtimeRuntimeStateReducer.reduce(runtimeState, event)
        val logEvent = VoiceRuntimeEventPolicy.logEvent(event)
        if (event.normalizedStateAfter.state == RealtimeLifecycleState.Failed) {
            RuntimeStateLogger.error(logEvent)
        } else {
            RuntimeStateLogger.info(logEvent)
        }
    }
}

internal object VoiceRuntimeEventPolicy {
    fun transitionEvent(
        transition: TaskVoiceTurnTransition,
        taskId: String?
    ): RealtimeRuntimeEvent {
        val normalizedTaskId = taskId?.trim()?.takeIf { it.isNotBlank() }
        return RealtimeRuntimeEvent(
            domain = RealtimeRuntimeDomain.Voice,
            eventType = transition.event,
            provider = "app",
            stateBefore = transition.before.phase.toRealtimeState(transition.before.reason),
            stateAfter = transition.after.phase.toRealtimeState(transition.after.reason),
            reason = transition.after.reason?.toRealtimeReason(),
            sessionId = normalizedTaskId,
            attributes = mapOf(
                "source" to transition.source,
                "voicePhaseBefore" to transition.before.phase.logKey,
                "voicePhaseAfter" to transition.after.phase.logKey,
                "transcriptPreview" to transition.after.transcriptPreview.takeIf { it.isNotBlank() }
            )
        )
    }

    fun logEvent(event: RealtimeRuntimeEvent): RuntimeStateLogEvent {
        val reason = event.reason?.takeIf { it.isNotBlank() }?.let { event.normalizedReason.key }
        return RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.VOICE,
            eventType = event.eventType,
            sessionId = event.sessionId,
            taskId = event.sessionId,
            provider = event.normalizedProvider.wireValue,
            stateBefore = event.normalizedStateBefore.wireValue,
            stateAfter = event.normalizedStateAfter.wireValue,
            reason = reason,
            attributes = event.attributes + mapOf(
                "normalizedStateBefore" to event.normalizedStateBefore.state.wireValue,
                "normalizedStateAfter" to event.normalizedStateAfter.state.wireValue
            )
        )
    }

    private fun TaskVoiceTurnPhase.toRealtimeState(reason: TaskVoiceCloseReason?): String {
        return when (reason) {
            TaskVoiceCloseReason.ProviderError,
            TaskVoiceCloseReason.TtsPlaybackFailed -> RealtimeLifecycleState.Failed.wireValue
            TaskVoiceCloseReason.ProviderClosed,
            TaskVoiceCloseReason.ManualAsrTimeout60s -> RealtimeLifecycleState.Closed.wireValue
            else -> when (this) {
                TaskVoiceTurnPhase.Idle -> RealtimeLifecycleState.Idle.wireValue
                TaskVoiceTurnPhase.AsrConnecting -> RealtimeLifecycleState.Connecting.wireValue
                TaskVoiceTurnPhase.AsrListening,
                TaskVoiceTurnPhase.AwaitingManualRelease,
                TaskVoiceTurnPhase.AgentSubmitting,
                TaskVoiceTurnPhase.TtsPlaying -> RealtimeLifecycleState.Active.wireValue
                TaskVoiceTurnPhase.Closed -> RealtimeLifecycleState.Closed.wireValue
            }
        }
    }

    private fun TaskVoiceCloseReason.toRealtimeReason(): String {
        return when (this) {
            TaskVoiceCloseReason.LifecycleCancel -> "lifecycle_cancelled"
            else -> logKey
        }
    }
}
