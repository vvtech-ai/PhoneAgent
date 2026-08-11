package com.vvtech.aiassistant.features.assistant_voice

internal enum class TaskVoiceTurnPhase(val logKey: String) {
    Idle("idle"),
    AsrConnecting("asr_connecting"),
    AsrListening("asr_listening"),
    AwaitingManualRelease("awaiting_manual_release"),
    AgentSubmitting("agent_submitting"),
    TtsPlaying("tts_playing"),
    Closed("closed")
}

internal enum class TaskVoiceCloseReason(val logKey: String) {
    ManualRelease("manual_release"),
    ManualAsrTimeout60s("manual_asr_timeout_60s"),
    ProviderClosed("provider_closed"),
    ProviderError("provider_error"),
    TtsPlaybackStarted("tts_playback_started"),
    TtsPlaybackCompleted("tts_playback_completed"),
    TtsPlaybackFailed("tts_playback_failed"),
    ManualTtsInterrupt("manual_tts_interrupt"),
    NoInterruptCapability("no_interrupt_capability"),
    CallAudioSuppressed("call_audio_suppressed"),
    LifecycleCancel("lifecycle_cancel"),
    UserClose("user_close")
}

internal data class TaskVoiceTurnSnapshot(
    val phase: TaskVoiceTurnPhase,
    val reason: TaskVoiceCloseReason? = null,
    val transcriptPreview: String = ""
)

internal data class TaskVoiceTurnTransition(
    val event: String,
    val before: TaskVoiceTurnSnapshot,
    val after: TaskVoiceTurnSnapshot,
    val source: String
) {
    fun toLogLine(): String =
        "VOICE_TURN_STATE event=$event " +
            "phaseBefore=${before.phase.logKey} phaseAfter=${after.phase.logKey} " +
            "reason=${after.reason?.logKey ?: "none"} source=${source.take(MaxSourceLength)} " +
            "text=${after.transcriptPreview}"
}

internal class TaskVoiceTurnStateMachine(
    private val logger: ((String) -> Unit)? = null,
    private val transitionListener: ((TaskVoiceTurnTransition) -> Unit)? = null
) {
    var snapshot: TaskVoiceTurnSnapshot = TaskVoiceTurnSnapshot(TaskVoiceTurnPhase.Idle)
        private set

    fun reset(reason: TaskVoiceCloseReason = TaskVoiceCloseReason.LifecycleCancel, source: String): TaskVoiceTurnTransition =
        transition(
            event = "reset",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = reason,
            source = source
        )

    fun close(reason: TaskVoiceCloseReason, source: String): TaskVoiceTurnTransition =
        transition(
            event = "close",
            nextPhase = TaskVoiceTurnPhase.Closed,
            reason = reason,
            source = source
        )

    fun onManualAsrPress(ttsPlaying: Boolean, source: String): TaskVoiceTurnTransition =
        transition(
            event = "manual_asr_press",
            nextPhase = TaskVoiceTurnPhase.AsrConnecting,
            reason = if (ttsPlaying) TaskVoiceCloseReason.ManualTtsInterrupt else null,
            source = source
        )

    fun onAsrReady(source: String): TaskVoiceTurnTransition =
        transition(
            event = "asr_ready",
            nextPhase = TaskVoiceTurnPhase.AsrListening,
            reason = null,
            source = source
        )

    fun onAsrPartial(text: String, source: String): TaskVoiceTurnTransition =
        transition(
            event = "asr_partial",
            nextPhase = TaskVoiceTurnPhase.AsrListening,
            reason = null,
            source = source,
            transcriptPreview = text
        )

    fun onAsrFinalBuffered(text: String, source: String): TaskVoiceTurnTransition =
        transition(
            event = "asr_final_buffered",
            nextPhase = TaskVoiceTurnPhase.AwaitingManualRelease,
            reason = null,
            source = source,
            transcriptPreview = text
        )

    fun onManualReleaseSubmit(text: String, source: String): TaskVoiceTurnTransition =
        transition(
            event = "manual_release_submit",
            nextPhase = TaskVoiceTurnPhase.AgentSubmitting,
            reason = TaskVoiceCloseReason.ManualRelease,
            source = source,
            transcriptPreview = text
        )

    fun onManualReleaseNoTranscript(source: String): TaskVoiceTurnTransition =
        transition(
            event = "manual_release_no_transcript",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.ManualRelease,
            source = source
        )

    fun onAgentSubmitting(text: String, source: String): TaskVoiceTurnTransition =
        transition(
            event = "agent_submitting",
            nextPhase = TaskVoiceTurnPhase.AgentSubmitting,
            reason = null,
            source = source,
            transcriptPreview = text
        )

    fun onTtsPlaybackStarted(source: String): TaskVoiceTurnTransition =
        transition(
            event = "tts_playback_started",
            nextPhase = TaskVoiceTurnPhase.TtsPlaying,
            reason = TaskVoiceCloseReason.TtsPlaybackStarted,
            source = source
        )

    fun onTtsPlaybackCompleted(source: String): TaskVoiceTurnTransition =
        transition(
            event = "tts_playback_completed",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.TtsPlaybackCompleted,
            source = source
        )

    fun onTtsPlaybackFailed(source: String): TaskVoiceTurnTransition =
        transition(
            event = "tts_playback_failed",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.TtsPlaybackFailed,
            source = source
        )

    fun onManualTtsInterrupt(source: String, startAsrAfter: Boolean): TaskVoiceTurnTransition =
        transition(
            event = "manual_tts_interrupt",
            nextPhase = if (startAsrAfter) TaskVoiceTurnPhase.AsrConnecting else TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.ManualTtsInterrupt,
            source = source
        )

    fun onManualAsrTimeout(source: String): TaskVoiceTurnTransition =
        transition(
            event = "manual_asr_timeout",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.ManualAsrTimeout60s,
            source = source
        )

    fun onProviderError(source: String): TaskVoiceTurnTransition =
        transition(
            event = "provider_error",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.ProviderError,
            source = source
        )

    fun onProviderClosed(source: String): TaskVoiceTurnTransition =
        transition(
            event = "provider_closed",
            nextPhase = TaskVoiceTurnPhase.Idle,
            reason = TaskVoiceCloseReason.ProviderClosed,
            source = source
        )

    private fun transition(
        event: String,
        nextPhase: TaskVoiceTurnPhase,
        reason: TaskVoiceCloseReason?,
        source: String,
        transcriptPreview: String = ""
    ): TaskVoiceTurnTransition {
        val before = snapshot
        val after = TaskVoiceTurnSnapshot(
            phase = nextPhase,
            reason = reason,
            transcriptPreview = transcriptPreview.previewForLog()
        )
        snapshot = after
        return TaskVoiceTurnTransition(
            event = event,
            before = before,
            after = after,
            source = source.ifBlank { "unknown" }
        ).also { transition ->
            logger?.invoke(transition.toLogLine())
            transitionListener?.invoke(transition)
        }
    }

    private fun String.previewForLog(): String {
        val normalized = trim().replace(Regex("\\s+"), " ")
        return when {
            normalized.isBlank() -> ""
            normalized.length <= MaxTranscriptPreviewLength -> normalized
            else -> normalized.take(MaxTranscriptPreviewLength) + "..."
        }
    }
}

private const val MaxTranscriptPreviewLength = 40
private const val MaxSourceLength = 48
