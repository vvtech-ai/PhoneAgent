package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.features.assistant_voice.VoiceTaskAsrEventCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceTaskAsrEventHandler
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexAudioRouteController
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexCompletionCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexCompletionController
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexPlaybackCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexPlaybackController
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexRetryCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceDuplexRetryController
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultUserId
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal enum class VoiceDuplexSpeechSource(val logKey: String) {
    AgentStreamDelta("agent_stream_delta"),
    AgentSignal("agent_signal"),
    VoicePrompt("voice_prompt"),
    BackendPrompt("backend_prompt"),
    RealtimeAssistant("realtime_assistant"),
    StructuredSpeak("structured_speak"),
    SyntheticPrompt("synthetic_prompt")
}
/**
 * Coordinates task voice turns in strict simplex order:
 * user-controlled ASR, assistant TTS, then idle until the next manual press.
 */
internal class VoiceDuplexCoordinator(
    private val viewModel: AssistantViewModel
) {
    private var taskAsrCaptureGeneration = 0L
    internal var dialogAsrActive = false
        set(value) {
            if (field && !value) taskAsrCaptureGeneration += 1
            field = value
        }
    private var awaitingManualReleaseFinal = false
    private val audioRouteController = VoiceDuplexAudioRouteController(viewModel)
    private val playbackController = VoiceDuplexPlaybackController(
        viewModel = viewModel,
        callbacks = object : VoiceDuplexPlaybackCallbacks {
            override var dialogAsrActive: Boolean
                get() = this@VoiceDuplexCoordinator.dialogAsrActive
                set(value) { this@VoiceDuplexCoordinator.dialogAsrActive = value }

            override var awaitingManualReleaseFinal: Boolean
                get() = this@VoiceDuplexCoordinator.awaitingManualReleaseFinal
                set(value) { this@VoiceDuplexCoordinator.awaitingManualReleaseFinal = value }

            override fun suspendDialogAudioForCall(reason: String) {
                this@VoiceDuplexCoordinator.suspendDialogAudioForCall(reason)
            }

            override fun releaseVoiceConversationAudioRoute(reason: String) {
                this@VoiceDuplexCoordinator.releaseVoiceConversationAudioRoute(reason)
            }

            override fun restoreNormalAudioMode(reason: String) {
                this@VoiceDuplexCoordinator.restoreNormalAudioMode(reason)
            }
        }
    )
    private val completionController = VoiceDuplexCompletionController(
        viewModel = viewModel,
        playbackController = playbackController,
        callbacks = object : VoiceDuplexCompletionCallbacks {
            override var dialogAsrActive: Boolean
                get() = this@VoiceDuplexCoordinator.dialogAsrActive
                set(value) { this@VoiceDuplexCoordinator.dialogAsrActive = value }

            override fun suspendDialogAudioForCall(reason: String) {
                this@VoiceDuplexCoordinator.suspendDialogAudioForCall(reason)
            }

            override fun restoreNormalAudioMode(reason: String) {
                this@VoiceDuplexCoordinator.restoreNormalAudioMode(reason)
            }
        }
    )
    private val retryController = VoiceDuplexRetryController(
        viewModel = viewModel,
        callbacks = object : VoiceDuplexRetryCallbacks {
            override var dialogAsrActive: Boolean
                get() = this@VoiceDuplexCoordinator.dialogAsrActive
                set(value) { this@VoiceDuplexCoordinator.dialogAsrActive = value }

            override fun restoreNormalAudioMode(reason: String) {
                this@VoiceDuplexCoordinator.restoreNormalAudioMode(reason)
            }

            override fun startOpenListening() {
                this@VoiceDuplexCoordinator.startOpenListening()
            }
        }
    )
    private val taskAsrEventHandler = VoiceTaskAsrEventHandler(
        viewModel = viewModel,
        callbacks = object : VoiceTaskAsrEventCallbacks {
            override var dialogAsrActive: Boolean
                get() = this@VoiceDuplexCoordinator.dialogAsrActive
                set(value) { this@VoiceDuplexCoordinator.dialogAsrActive = value }

            override var awaitingManualReleaseFinal: Boolean
                get() = this@VoiceDuplexCoordinator.awaitingManualReleaseFinal
                set(value) { this@VoiceDuplexCoordinator.awaitingManualReleaseFinal = value }

            override fun suspendDialogAudioForCall(reason: String) {
                this@VoiceDuplexCoordinator.suspendDialogAudioForCall(reason)
            }

            override fun ignoreDuringSimplexPlayback(eventName: String): Boolean =
                ignoreDialogAsrDuringSimplexPlayback(eventName)

            override fun restoreNormalAudioMode() {
                this@VoiceDuplexCoordinator.restoreNormalAudioMode()
            }

            override fun pauseAfterRealtimeFailure(reason: String, closeTts: Boolean, closeAsr: Boolean) {
                pauseVoiceAfterRealtimeFailure(reason, closeTts, closeAsr)
            }
        }
    )

    internal fun reset() {
        invalidateTaskAsrCapture()
        dialogAsrActive = false
        awaitingManualReleaseFinal = false
        playbackController.resetSpeechState()
        releaseVoiceConversationAudioRoute("reset")
    }

    internal fun hasPendingManualReleaseFinal(): Boolean = awaitingManualReleaseFinal

    internal fun cancelManualReleaseLateFinal(reason: String, closeSocket: Boolean) {
        invalidateTaskAsrCapture()
        if (!awaitingManualReleaseFinal && !dialogAsrActive) {
            if (closeSocket) {
                viewModel.taskAsrClient.closeNow(reason.take(120))
            }
            return
        }
        with(viewModel) {
            internalLog(
                "VOICE_DUPLEX cancel manual release late final reason=$reason closeSocket=$closeSocket " +
                    "voiceConnecting=${internalUiState.value.voiceConnecting} " +
                    "apiAsrListening=${internalUiState.value.apiAsrListening}"
            )
            awaitingManualReleaseFinal = false
            dialogAsrActive = false
            if (closeSocket) {
                taskAsrClient.closeNow(reason.take(120))
            }
        }
    }

    internal fun clearOpenListeningForNewTaskEntry(reason: String) {
        with(viewModel) {
            invalidateTaskAsrCapture()
            internalLog(
                "VOICE_DUPLEX clear open listening for new task reason=$reason " +
                    "dialogAsrActive=$dialogAsrActive apiAsrListening=${internalUiState.value.apiAsrListening} " +
                    "voiceConnecting=${internalUiState.value.voiceConnecting}"
            )
            manualAsrReleaseFallbackJob?.cancel()
            manualAsrReleaseFallbackJob = null
            manualAsrButtonPressed = false
            pendingManualAsrFinalTranscript = null
            manualAsrPressGeneration += 1
            dialogAsrActive = false
            awaitingManualReleaseFinal = false
            backendSpeechFallbackActive = false
            platformSpeechFallbackStarted = false
            taskAsrClient.closeNow("new_task_entry_${reason.take(96)}")
            liveSpeechClient.stop()
            speechRecognizer.stop()
            if (!localTtsPlaying && !internalUiState.value.localTtsSpeaking && !internalUiState.value.apiTtsPlaying) {
                restoreNormalAudioMode()
            }
            internalUiState.update {
                it.copy(
                    apiAsrListening = false,
                    manualAsrFinalizing = false,
                    apiAsrPartialText = null,
                    voiceConnecting = false,
                    listening = false,
                    voiceManuallyPaused = false,
                    voiceBackgroundPaused = false
                )
            }
        }
    }

    internal fun suspendDialogAudioForCall(reason: String) {
        with(viewModel) {
            invalidateTaskAsrCapture()
            val state = internalUiState.value
            val hadDialogAudio = dialogAsrActive ||
                state.apiAsrListening ||
                state.apiTtsPlaying ||
                state.localTtsSpeaking ||
                state.voiceConnecting ||
                state.voiceActive ||
                state.listening ||
                localTtsPlaying ||
                audioRecorder.isRecording()
            logOutboundCallAudioGate(
                "suspendDialogAudioForCall:$reason hadDialogAudio=$hadDialogAudio " +
                    "dialogAsrActive=$dialogAsrActive " +
                    "audioRecorder=${audioRecorder.isRecording()} localTtsPlaying=$localTtsPlaying"
            )
            if (hadDialogAudio) {
                internalLog(
                    "VOICE_DUPLEX suspend dialog audio for call reason=$reason " +
                        "showAiCallPage=${state.showAiCallPage} pendingAiCallLaunch=$pendingAiCallLaunch " +
                        "outboundCallAudioSuppressed=$outboundCallAudioSuppressed " +
                        "currentCallId=${state.currentCallId.orEmpty()} taskId=${state.taskId.orEmpty()}"
                )
            }
            manualAsrReleaseFallbackJob?.cancel()
            manualAsrReleaseFallbackJob = null
            manualAsrButtonPressed = false
            pendingManualAsrFinalTranscript = null
            dialogAsrActive = false
            awaitingManualReleaseFinal = false
            voiceRuntimeHandler.cancelAsrInputWatchdogs("call_audio_suppressed_$reason")
            playbackController.resetSpeechState()
            localTtsPlaying = false
            backendSpeechFallbackActive = false
            platformSpeechFallbackStarted = false
            if (audioRecorder.isRecording()) {
                audioRecorder.stop()
            }
            ttsBridge.interrupt()
            assistantSpeechPlayer.stop()
            taskAsrClient.closeNow("call_audio_suppressed_$reason")
            liveSpeechClient.stop()
            speechRecognizer.stop()
            restoreNormalAudioMode()
            internalUiState.update {
                it.copy(
                    listening = false,
                    voiceConnecting = false,
                    voiceActive = false,
                    voiceManuallyPaused = false,
                    voiceBackgroundPaused = false,
                    liveUserTranscript = null,
                    liveAssistantTranscript = null,
                    apiAsrListening = false,
                    manualAsrFinalizing = false,
                    apiAsrPartialText = null,
                    apiTtsPlaying = false,
                    localTtsSpeaking = false
                )
            }
        }
    }

    internal fun prepareForRealtimeSessionStart(reason: String) {
        invalidateTaskAsrCapture()
        if (dialogAsrActive) {
            viewModel.internalLog(
                "VOICE_DUPLEX clearing dialog ASR before realtime start reason=$reason " +
                    "dialogAsrActive=$dialogAsrActive"
            )
        }
        dialogAsrActive = false
        releaseVoiceConversationAudioRoute("prepare_realtime:$reason")
    }

    internal fun startOpenListening() {
        with(viewModel) {
            AppFileLogger.d("TTS_DIAG", "startApiListening called, channel=$activeInteractionChannel")
            internalLog("VOICE_DUPLEX startOpenListening via task ASR")
            val callAudioSuppressed = isOutboundCallAudioSuppressed()
            logOutboundCallAudioGate("startOpenListening_entry", callAudioSuppressed)
            if (callAudioSuppressed) {
                suspendDialogAudioForCall("start_open_listening_call_active")
                return
            }
            if (internalUiState.value.voiceManuallyPaused) {
                internalLog("VOICE_DUPLEX startOpenListening skipped while manually paused")
                return
            }
            if (internalUiState.value.voiceBackgroundPaused) {
                internalLog("VOICE_DUPLEX startOpenListening skipped while background paused")
                return
            }
            if (internalUiState.value.apiTtsPlaying || internalUiState.value.localTtsSpeaking || localTtsPlaying) {
                internalLog("VOICE_DUPLEX startOpenListening skipped during assistant playback")
                return
            }
            if (internalUiState.value.voiceConnecting && dialogAsrActive && !internalUiState.value.apiTtsPlaying) {
                if (internalUiState.value.apiAsrListening) {
                    internalLog("VOICE_DUPLEX startOpenListening recovered ready ASR from pending state")
                    internalUiState.update {
                        it.copy(
                            listening = true,
                            voiceConnecting = false,
                            processingTurn = false,
                            apiAsrPartialText = null,
                            status = localizedListeningStatus()
                        )
                    }
                    return
                }
                internalLog("VOICE_DUPLEX startOpenListening ignored because ASR connection is already pending")
                return
            }
            releaseVoiceConversationAudioRoute("start_open_listening")
            if (canUseRealtimeSessionForOpenListening()) {
                internalLog(
                    "VOICE_DUPLEX startOpenListening uses existing realtime session " +
                        "voiceActive=${internalUiState.value.voiceActive} voiceConnecting=${internalUiState.value.voiceConnecting}"
                )
                dialogAsrActive = false
                internalUiState.update {
                    it.copy(
                        apiAsrListening = it.voiceActive,
                        apiAsrPartialText = null,
                        apiTtsPlaying = false,
                        voiceConnecting = it.voiceConnecting,
                        listening = it.voiceActive,
                        processingTurn = false,
                        status = localizedListeningStatus()
                    )
                }
                voiceRuntimeHandler.startAsrInputWatchdog("open_existing_realtime")
                return
            }
            playbackController.resetSpeechState()
            val captureGeneration = ++taskAsrCaptureGeneration
            viewModel.voiceRuntimeHandler.startTaskVoiceAsrSession(
                startReason = "open_listening",
                onEvent = { event -> handleDialogAsrEvent(captureGeneration, event) },
                beforeStart = {
                    restoreNormalAudioMode()
                    dialogAsrActive = true
                    internalUiState.update {
                        it.copy(
                            apiAsrListening = false,
                            apiAsrPartialText = null,
                            apiTtsPlaying = false,
                            localTtsSpeaking = false,
                            voiceManuallyPaused = false,
                            voiceBackgroundPaused = false,
                            voiceConnecting = true,
                            listening = false,
                            processingTurn = false,
                            status = localizedConnectingVoiceStatus()
                        )
                    }
                    voiceRuntimeHandler.startAsrInputWatchdog("open_dialog_asr")
                }
            )
        }
    }

    internal fun stopOpenListening(
        preservePlaybackRoute: Boolean = false,
        awaitLateFinal: Boolean = false
    ) {
        with(viewModel) {
            internalLog("VOICE_DUPLEX stopOpenListening via task ASR awaitLateFinal=$awaitLateFinal")
            if (!awaitLateFinal) invalidateTaskAsrCapture()
            dialogAsrActive = awaitLateFinal
            awaitingManualReleaseFinal = awaitLateFinal
            taskAsrClient.stop()
            val keepPlaybackRoute = preservePlaybackRoute ||
                internalUiState.value.apiTtsPlaying ||
                internalUiState.value.localTtsSpeaking ||
                localTtsPlaying
            if (keepPlaybackRoute) {
                keepSpeechOutputOnSpeaker()
            } else {
                restoreNormalAudioMode()
            }
            internalUiState.update {
                val showPausedStatus = it.voiceManuallyPaused || it.voiceBackgroundPaused
                it.copy(
                    apiAsrListening = false,
                    apiAsrPartialText = null,
                    listening = false,
                    voiceConnecting = false,
                    status = if (showPausedStatus) localizedPausedTapToContinueStatus() else it.status
                )
            }
        }
    }

    internal fun feedAgentTextDelta(delta: String) =
        playbackController.feedAgentTextDelta(delta)

    internal fun feedAgentSignalText(text: String) =
        playbackController.feedAgentSignalText(text)

    internal fun flushAgentTts() =
        playbackController.flushAgentTts()

    internal fun onAgentTtsPlaybackComplete() =
        completionController.onAgentTtsPlaybackComplete()

    internal fun onAgentTtsPlaybackFailed(error: Throwable?) =
        completionController.onAgentTtsPlaybackFailed(error)

    internal fun onAgentTtsPlaybackStarted() {
        playbackController.onAgentTtsPlaybackStarted()
    }

    internal fun onAgentTtsSentencePreparing(sentence: String) {
        playbackController.onAgentTtsSentencePreparing(sentence)
    }

    internal fun onAgentTtsAudioReady() {
        playbackController.onAgentTtsAudioReady()
    }

    internal fun speakLocal(
        text: String,
        source: VoiceDuplexSpeechSource,
        languageCode: String,
        onStart: (() -> Unit)? = null,
        onDone: (() -> Unit)? = null,
        onError: (() -> Unit)? = onDone
    ) = completionController.speakLocal(text, source, languageCode, onStart, onDone, onError)

    private fun handleDialogAsrEvent(captureGeneration: Long, event: TaskVoiceAsrEvent) {
        viewModel.viewModelScope.launch {
            if (captureGeneration != taskAsrCaptureGeneration) {
                viewModel.internalLog(
                    "VOICE_DUPLEX stale ASR event dropped captureGeneration=$captureGeneration " +
                        "activeGeneration=$taskAsrCaptureGeneration event=${event.javaClass.simpleName} " +
                        "taskId=${viewModel.internalUiState.value.taskId.orEmpty()}"
                )
                return@launch
            }
            taskAsrEventHandler.handle(event)
        }
    }

    private fun invalidateTaskAsrCapture() { taskAsrCaptureGeneration += 1 }
    private fun pauseVoiceAfterRealtimeFailure(
        reason: String,
        closeTts: Boolean,
        closeAsr: Boolean
    ) = completionController.pauseVoiceAfterRealtimeFailure(reason, closeTts, closeAsr)

    internal fun markPausedIfVoiceCanContinue(reason: String) =
        completionController.markPausedIfVoiceCanContinue(reason)

    private fun ignoreDialogAsrDuringSimplexPlayback(eventName: String): Boolean {
        val state = viewModel.internalUiState.value
        val assistantPlaybackActive = shouldIgnoreTaskAsrEventDuringSimplexPlayback(
            apiTtsPlaying = state.apiTtsPlaying,
            localTtsSpeaking = state.localTtsSpeaking,
            localTtsPlaying = viewModel.localTtsPlaying
        )
        if (!assistantPlaybackActive) return false
        viewModel.internalLog(
            "VOICE_DUPLEX dialog ASR $eventName ignored during simplex playback " +
                "dialogAsrActive=$dialogAsrActive"
        )
        dialogAsrActive = false
        awaitingManualReleaseFinal = false
        viewModel.voiceRuntimeHandler.cancelAsrInputWatchdogs("simplex_ignore_$eventName".take(120))
        viewModel.taskAsrClient.stop()
        viewModel.internalUiState.update {
            it.copy(
                apiAsrListening = false,
                apiAsrPartialText = null,
                voiceConnecting = false,
                listening = false
            )
        }
        return true
    }

    private fun ensureVoiceConversationAudioRoute(reason: String) =
        audioRouteController.ensureVoiceConversationAudioRoute(reason)

    private fun releaseVoiceConversationAudioRoute(reason: String) =
        audioRouteController.releaseVoiceConversationAudioRoute(reason)

    private fun canUseRealtimeSessionForOpenListening(): Boolean {
        return false
    }

    internal fun restartListeningAfterDroppedTranscript(reason: String) =
        retryController.restartListeningAfterDroppedTranscript(reason)

    private fun restoreNormalAudioMode(reason: String = "unspecified", force: Boolean = false) =
        audioRouteController.restoreNormalAudioMode(reason, force)

    private fun keepSpeechOutputOnSpeaker() =
        audioRouteController.keepSpeechOutputOnSpeaker()

}
