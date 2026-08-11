package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceDuplexSpeechSource
import com.vvtech.aiassistant.features.assistant.containsTransportNetworkError
import com.vvtech.aiassistant.features.assistant.localizedListeningStatus
import com.vvtech.aiassistant.features.assistant.localizedPausedTapToContinueStatus
import com.vvtech.aiassistant.features.assistant.localizedTapMicToContinueStatus
import com.vvtech.aiassistant.features.assistant.networkTaskErrorStatusMessage
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.flow.update

internal interface VoiceDuplexCompletionCallbacks {
    var dialogAsrActive: Boolean
    fun suspendDialogAudioForCall(reason: String)
    fun restoreNormalAudioMode(reason: String)
}

internal class VoiceDuplexCompletionController(
    private val viewModel: AssistantViewModel,
    private val playbackController: VoiceDuplexPlaybackController,
    private val callbacks: VoiceDuplexCompletionCallbacks
) {
    fun onAgentTtsPlaybackComplete() { with(viewModel) {
        val callAudioSuppressed = isOutboundCallAudioSuppressed()
        logOutboundCallAudioGate("agent_tts_playback_complete", callAudioSuppressed)
        if (callAudioSuppressed) {
            callbacks.suspendDialogAudioForCall("agent_tts_playback_complete")
            return
        }
        val channel = activeInteractionChannel
        val asrListening = internalUiState.value.apiAsrListening
        val recording = audioRecorder.isRecording()
        AppFileLogger.d(
            "TTS_DIAG",
            "onAllPlaybackComplete channel=$channel asrListening=$asrListening recording=$recording"
        )
        internalLog("VOICE_DUPLEX agent TTS playback complete")
        voiceRuntimeHandler.recordTtsPlaybackCompleted("agent_tts_playback_complete")
        if (internalUiState.value.voiceManuallyPaused || internalUiState.value.voiceBackgroundPaused) {
            playbackController.resetAfterPlayback()
            internalUiState.update {
                it.copy(
                    apiTtsPlaying = false,
                    localTtsSpeaking = false,
                    listening = false,
                    voiceConnecting = false,
                    apiAsrListening = false,
                    apiAsrPartialText = null,
                    status = localizedTapMicToContinueStatus()
                )
            }
            return
        }
        val responseType = internalUiState.value.let { st ->
            when {
                st.agentCallResult != null -> "CALL_RESULT"
                st.agentCallSpec != null -> "MAKE_CALL"
                st.agentQuestions != null -> "ASK_USER"
                st.agentOptions != null -> "SHOW_OPTIONS"
                st.agentPermissionRequest != null -> "REQUEST_PERMISSION"
                st.agentDocumentRequest != null -> "IMPORT_DOCUMENT_REQUEST"
                else -> "TEXT_REPLY"
            }
        }
        AppFileLogger.d(
            "TTS_DIAG",
            "onAllPlaybackComplete responseType=$responseType " +
                "dialogAsrActive=${callbacks.dialogAsrActive}"
        )
        playbackController.resetAfterPlayback()
        internalUiState.update {
            it.copy(
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                listening = false,
                voiceConnecting = false
            )
        }
        if (responseType == "CALL_RESULT") {
            internalUiState.update { it.copy(status = localizedTapMicToContinueStatus()) }
        } else {
            markPausedIfVoiceCanContinue("agent_tts_complete_manual_gate")
        }
    } }

    fun onAgentTtsPlaybackFailed(error: Throwable?) {
        viewModel.voiceRuntimeHandler.recordTtsPlaybackFailed("agent_tts_playback_failed")
        pauseVoiceAfterRealtimeFailure(
            reason = "agent_tts_failed:${error?.message.orEmpty().ifBlank { "unknown" }}",
            closeTts = true,
            closeAsr = true
        )
    }

    fun speakLocal(
        text: String,
        source: VoiceDuplexSpeechSource,
        languageCode: String,
        onStart: (() -> Unit)? = null,
        onDone: (() -> Unit)? = null,
        onError: (() -> Unit)? = onDone
    ) {
        val normalized = text.trim()
        if (normalized.isBlank()) return
        if (viewModel.isOutboundCallAudioSuppressed()) {
            AppFileLogger.i(
                "TTS_DIAG",
                "playback suppressed reason=speak_local_call_audio_suppressed source=${source.logKey} " +
                    viewModel.outboundCallAudioGateSnapshot()
            )
            callbacks.suspendDialogAudioForCall("speak_local_${source.logKey}")
            return
        }
        playbackController.rememberSpeech(source, normalized, append = false)
        viewModel.localTtsPlaying = true
        viewModel.voiceRuntimeHandler.recordTtsPlaybackStarted("local_tts:${source.logKey}")
        playbackController.prepareSimplexPlayback(source, "local_tts")
        viewModel.internalUiState.update {
            it.copy(
                apiTtsPlaying = true,
                localTtsSpeaking = true,
                status = if (it.voiceManuallyPaused) {
                    viewModel.localizedPausedTapToContinueStatus()
                } else {
                    viewModel.localizedListeningStatus()
                }
            )
        }
        viewModel.internalLog(
            "VOICE_DUPLEX unified TTS started source=${source.logKey} " +
                "language=$languageCode text=${previewText(normalized)}"
        )
        onStart?.invoke()
        viewModel.ttsBridge.feedSignalText(
            normalized,
            onComplete = {
                finishLocalPlayback(source)
                onDone?.invoke()
            },
            onError = {
                finishLocalPlayback(source)
                (onError ?: onDone)?.invoke()
            }
        )
    }

    fun pauseVoiceAfterRealtimeFailure(
        reason: String,
        closeTts: Boolean,
        closeAsr: Boolean
    ) { with(viewModel) {
        internalLog("VOICE_DUPLEX recoverable pause reason=$reason closeTts=$closeTts closeAsr=$closeAsr")
        val pauseStatus = if (containsTransportNetworkError(reason)) {
            networkTaskErrorStatusMessage(currentVoiceLanguage())
        } else {
            localizedPausedTapToContinueStatus()
        }
        playbackController.resetAfterPlayback()
        if (closeTts) {
            ttsBridge.closeRealtime(reason.take(120))
            assistantSpeechPlayer.stop()
            localTtsPlaying = false
        }
        if (closeAsr) {
            taskAsrClient.closeNow(reason.take(120))
        }
        voiceRuntimeHandler.cancelAsrInputWatchdogs(reason.take(120))
        callbacks.dialogAsrActive = false
        backendSpeechFallbackActive = false
        platformSpeechFallbackStarted = false
        internalUiState.update {
            it.copy(
                voiceManuallyPaused = true,
                voiceBackgroundPaused = false,
                voiceActive = true,
                listening = false,
                voiceConnecting = false,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                error = null,
                status = pauseStatus
            )
        }
    } }

    fun markPausedIfVoiceCanContinue(reason: String) { with(viewModel) {
        val state = internalUiState.value
        logOutboundCallAudioGate("markPausedIfVoiceCanContinue:$reason")
        if (!shouldShowPausedPrompt(state)) {
            return
        }
        internalLog("VOICE_DUPLEX paused prompt reason=$reason")
        internalUiState.update {
            it.copy(
                listening = false,
                voiceConnecting = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                voiceManuallyPaused = state.voiceManuallyPaused,
                voiceBackgroundPaused = state.voiceBackgroundPaused,
                error = null,
                status = if (state.voiceManuallyPaused || state.voiceBackgroundPaused) {
                    localizedPausedTapToContinueStatus()
                } else {
                    localizedTapMicToContinueStatus()
                }
            )
        }
    } }

    private fun finishLocalPlayback(source: VoiceDuplexSpeechSource) { with(viewModel) {
        internalLog("VOICE_DUPLEX local TTS finished source=${source.logKey}")
        localTtsPlaying = false
        playbackController.clearSpeechIfSource(source)
        if (callbacks.dialogAsrActive) {
            finishSpeakingWithReadyAsrOrPaused("local_tts_complete_dialog_active")
        } else {
            playbackController.resetAfterPlayback()
            internalUiState.update {
                it.copy(
                    apiTtsPlaying = false,
                    apiAsrListening = false,
                    apiAsrPartialText = null
                )
            }
            markPausedIfVoiceCanContinue("local_tts_complete_no_asr")
        }
    } }

    private fun finishSpeakingWithReadyAsrOrPaused(reason: String) { with(viewModel) {
        callbacks.dialogAsrActive = false
        callbacks.restoreNormalAudioMode("unspecified")
        internalUiState.update {
            it.copy(
                apiTtsPlaying = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                localTtsSpeaking = false,
                voiceConnecting = false,
                listening = false
            )
        }
        markPausedIfVoiceCanContinue(reason)
    } }

    private fun shouldShowPausedPrompt(state: Index9AssistantUiState): Boolean {
        return viewModel.activeInteractionChannel == InteractionChannel.VOICE &&
            !viewModel.isOutboundCallAudioSuppressed() &&
            !state.processingTurn &&
            !state.apiTtsPlaying &&
            !state.localTtsSpeaking &&
            !state.voiceConnecting &&
            !state.showAiCallPage &&
            state.agentCallResult == null
    }
}
