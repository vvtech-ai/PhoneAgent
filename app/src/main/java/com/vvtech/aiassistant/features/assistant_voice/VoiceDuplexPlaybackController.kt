package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceDuplexSpeechSource
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.flow.update

internal interface VoiceDuplexPlaybackCallbacks {
    var dialogAsrActive: Boolean
    var awaitingManualReleaseFinal: Boolean
    fun suspendDialogAudioForCall(reason: String)
    fun releaseVoiceConversationAudioRoute(reason: String)
    fun restoreNormalAudioMode(reason: String)
}

internal class VoiceDuplexPlaybackController(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceDuplexPlaybackCallbacks
) {
    private var activeSpeechSource: VoiceDuplexSpeechSource? = null
    private var activeSpeechText: String = ""

    fun resetSpeechState() {
        activeSpeechSource = null
        activeSpeechText = ""
    }

    fun resetAfterPlayback() {
        resetSpeechState()
        callbacks.restoreNormalAudioMode("unspecified")
    }

    fun clearSpeechIfSource(source: VoiceDuplexSpeechSource) {
        if (activeSpeechSource == source) {
            resetSpeechState()
        }
    }

    fun rememberSpeech(
        source: VoiceDuplexSpeechSource,
        text: String?,
        append: Boolean
    ) {
        activeSpeechSource = source
        val normalized = text?.trim().orEmpty()
        if (normalized.isBlank()) return
        activeSpeechText = if (append && activeSpeechText.isNotBlank()) {
            (activeSpeechText + normalized).takeLast(MaxSpeechTextWindow)
        } else {
            normalized.takeLast(MaxSpeechTextWindow)
        }
    }

    fun feedAgentTextDelta(delta: String) {
        val voiceMode = isVoiceMode()
        if (delta.isEmpty() || !voiceMode) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=agent_text_delta_not_voice_or_empty " +
                    "isVoiceMode=$voiceMode deltaEmpty=${delta.isEmpty()}"
            )
            return
        }
        if (viewModel.isOutboundCallAudioSuppressed()) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=agent_text_delta_call_audio_suppressed " +
                    viewModel.outboundCallAudioGateSnapshot()
            )
            callbacks.suspendDialogAudioForCall("agent_text_delta")
            return
        }
        rememberSpeech(VoiceDuplexSpeechSource.AgentStreamDelta, delta, append = true)
        prepareSimplexPlayback(VoiceDuplexSpeechSource.AgentStreamDelta, "agent_text_delta")
        viewModel.ttsBridge.feedTextDelta(delta)
    }

    fun feedAgentSignalText(text: String) {
        val normalized = text.trim()
        val voiceMode = isVoiceMode()
        if (normalized.isBlank() || !voiceMode) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=agent_signal_not_voice_or_blank " +
                    "isVoiceMode=$voiceMode textBlank=${normalized.isBlank()}"
            )
            return
        }
        val callAudioSuppressed = viewModel.isOutboundCallAudioSuppressed()
        viewModel.logOutboundCallAudioGate(
            "feedAgentSignalText text=${previewText(normalized.take(80))}",
            callAudioSuppressed
        )
        if (callAudioSuppressed) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=agent_signal_call_audio_suppressed " +
                    viewModel.outboundCallAudioGateSnapshot()
            )
            callbacks.suspendDialogAudioForCall("agent_signal")
            return
        }
        rememberSpeech(VoiceDuplexSpeechSource.AgentSignal, normalized, append = false)
        prepareSimplexPlayback(VoiceDuplexSpeechSource.AgentSignal, "agent_signal")
        viewModel.ttsBridge.feedSignalText(normalized, languageCode = viewModel.voiceLanguageCode)
    }

    fun flushAgentTts() {
        if (viewModel.isOutboundCallAudioSuppressed()) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=agent_tts_flush_call_audio_suppressed " +
                    viewModel.outboundCallAudioGateSnapshot()
            )
            callbacks.suspendDialogAudioForCall("agent_tts_flush")
            return
        }
        if (isVoiceMode()) {
            viewModel.ttsBridge.flush()
        } else {
            AppFileLogger.i("TTS_DIAG", "playback suppressed reason=agent_tts_flush_not_voice")
        }
    }

    fun onAgentTtsPlaybackStarted() {
        viewModel.voiceRuntimeHandler.recordTtsPlaybackStarted("agent_tts_playback_started")
        prepareSimplexPlayback(activeSpeechSource ?: VoiceDuplexSpeechSource.AgentSignal, "agent_tts_playback_started")
    }

    fun onAgentTtsSentencePreparing(sentence: String) {
        val source = activeSpeechSource ?: VoiceDuplexSpeechSource.AgentSignal
        if (activeSpeechText.isBlank() && sentence.isNotBlank()) {
            rememberSpeech(source, sentence, append = false)
        }
        prepareSimplexPlayback(source, "agent_tts_sentence_preparing")
    }

    fun onAgentTtsAudioReady() {
        prepareSimplexPlayback(activeSpeechSource ?: VoiceDuplexSpeechSource.AgentSignal, "agent_tts_audio_ready")
    }

    fun prepareSimplexPlayback(source: VoiceDuplexSpeechSource, reason: String) {
        if (viewModel.isOutboundCallAudioSuppressed()) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=simplex_playback_call_audio_suppressed " +
                    "source=${source.logKey} state=${viewModel.outboundCallAudioGateSnapshot()}"
            )
            callbacks.suspendDialogAudioForCall("simplex_playback_$reason")
            return
        }
        val state = viewModel.internalUiState.value
        val hadAsr = callbacks.dialogAsrActive ||
            state.apiAsrListening ||
            state.voiceConnecting ||
            state.listening
        if (hadAsr) {
            viewModel.internalLog(
                "VOICE_DUPLEX simplex playback clears ASR source=${source.logKey} reason=$reason " +
                    "dialogAsrActive=${callbacks.dialogAsrActive} apiAsr=${state.apiAsrListening}"
            )
        }
        callbacks.dialogAsrActive = false
        callbacks.awaitingManualReleaseFinal = false
        viewModel.voiceRuntimeHandler.cancelAsrInputWatchdogs("simplex_playback_$reason".take(120))
        viewModel.taskAsrClient.stop()
        callbacks.releaseVoiceConversationAudioRoute("simplex_playback:${source.logKey}:$reason")
        viewModel.internalUiState.update {
            it.copy(
                apiTtsPlaying = true,
                apiAsrListening = false,
                apiAsrPartialText = null,
                voiceConnecting = false,
                listening = false
            )
        }
    }

    private fun isVoiceMode(): Boolean =
        viewModel.activeInteractionChannel == InteractionChannel.VOICE

    private companion object {
        const val MaxSpeechTextWindow = 600
    }
}
