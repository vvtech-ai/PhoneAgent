package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal data class AgentStreamTtsBridgeRuntime(
    val isVoiceMode: () -> Boolean,
    val isCallDialogAudioSuppressed: () -> Boolean,
    val outboundCallAudioGateSnapshot: () -> String,
    val previewText: (String?) -> String
)

internal data class AgentStreamTtsBridgeCallbacks(
    val feedAgentTextDelta: (String) -> Unit,
    val feedAgentSignalText: (String) -> Unit,
    val flushAgentTts: () -> Unit,
    val suspendDialogAudioForCall: (String) -> Unit,
    val logOutboundCallAudioGate: (String) -> Unit
)

internal class AgentStreamTtsBridgeHandler(
    private val runtime: AgentStreamTtsBridgeRuntime,
    private val callbacks: AgentStreamTtsBridgeCallbacks
) {
    fun onDelta(delta: String) {
        val voice = runtime.isVoiceMode()
        logTts(
            eventType = "TTS_STREAM_DELTA_RECEIVED",
            result = if (voice && delta.isNotEmpty()) "eligible" else "skipped",
            reason = if (!voice) "not_voice_mode" else if (delta.isEmpty()) "empty_delta" else "stream_delta",
            attributes = mapOf("textLength" to delta.length.toString())
        )
        if (!voice || delta.isEmpty()) {
            return
        }
        if (runtime.isCallDialogAudioSuppressed()) {
            logTts("TTS_STREAM_DELTA_BLOCKED", "blocked", "call_audio_suppressed")
            callbacks.suspendDialogAudioForCall(ReasonStreamDelta)
            return
        }
        callbacks.feedAgentTextDelta(delta)
    }

    fun onSignal(text: String) {
        val voice = runtime.isVoiceMode()
        logTts(
            eventType = "TTS_SIGNAL_RECEIVED",
            result = if (voice && text.isNotBlank()) "eligible" else "skipped",
            reason = if (!voice) "not_voice_mode" else if (text.isBlank()) "blank_text" else "agent_signal",
            attributes = mapOf(
                "textLength" to text.length.toString(),
                "callAudioSuppressed" to runtime.isCallDialogAudioSuppressed().toString()
            )
        )
        if (!voice || text.isBlank()) {
            return
        }
        if (runtime.isCallDialogAudioSuppressed()) {
            logTts("TTS_SIGNAL_BLOCKED", "blocked", "call_audio_suppressed")
            callbacks.logOutboundCallAudioGate("maybeTtsSignal_suppressed")
            callbacks.suspendDialogAudioForCall(ReasonSignalText)
            return
        }
        try {
            callbacks.feedAgentSignalText(text)
            logTts("TTS_SIGNAL_ROUTED", "completed", "signal_forwarded")
        } catch (e: Exception) {
            RuntimeStateLogger.error(
                RuntimeStateLogEvent(
                    domain = RuntimeStateLogDomain.TTS,
                    eventType = "TTS_SIGNAL_FAILED",
                    result = "failed",
                    reason = "signal_forward_failure",
                    attributes = mapOf("exceptionType" to e.javaClass.simpleName)
                ),
                e
            )
        }
    }

    fun onFlush() {
        val voice = runtime.isVoiceMode()
        logTts(
            eventType = "TTS_FLUSH_REQUESTED",
            result = if (voice) "eligible" else "skipped",
            reason = if (voice) "agent_flush" else "not_voice_mode"
        )
        if (!voice) {
            return
        }
        if (runtime.isCallDialogAudioSuppressed()) {
            logTts("TTS_FLUSH_BLOCKED", "blocked", "call_audio_suppressed")
            callbacks.suspendDialogAudioForCall(ReasonTtsFlush)
            return
        }
        callbacks.flushAgentTts()
        logTts("TTS_FLUSH_ROUTED", "completed", "flush_forwarded")
    }

    private fun logTts(
        eventType: String,
        result: String,
        reason: String,
        attributes: Map<String, String?> = emptyMap()
    ) {
        RuntimeStateLogger.debug(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.TTS,
                eventType = eventType,
                result = result,
                reason = reason,
                attributes = attributes
            )
        )
    }

    private companion object {
        const val ReasonStreamDelta = "agent_stream_delta"
        const val ReasonSignalText = "agent_signal_text"
        const val ReasonTtsFlush = "agent_tts_flush"
    }
}
