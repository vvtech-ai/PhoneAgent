package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.TaskVoiceCloseReason
import com.vvtech.aiassistant.features.assistant.VoicePauseSource
import com.vvtech.aiassistant.features.assistant.localizedConnectingVoiceStatus
import com.vvtech.aiassistant.features.assistant.localizedPausedTapToContinueStatus
import com.vvtech.aiassistant.features.assistant.localizedTapMicToContinueStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUiStateReducer
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant_recording.CallRecordingPlaybackControl
import com.vvtech.aiassistant.features.assistant_tasks.shouldClearCallResultForContinuation
import com.vvtech.aiassistant.features.assistant.voicePauseFlagsFor
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class VoiceManualControlHandler(
    private val viewModel: AssistantViewModel
) {
    fun onManualAsrPress() { with(viewModel) {
        if (internalUiState.value.manualAsrFinalizing) {
            internalLog("MANUAL_ASR press blocked reason=release_finalizing")
            return@with
        }
        CallRecordingPlaybackControl.stopActiveForVoiceInput()
        autoResumeListeningJob?.cancel()
        val releaseCompletionPending = manualAsrReleaseFallbackJob?.isActive == true
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        manualAsrPressGeneration += 1
        if (releaseCompletionPending || voiceDuplexCoordinator.hasPendingManualReleaseFinal()) {
            internalLog(
                "MANUAL_ASR press clears prior release completion before new session " +
                    "tailCapturePending=$releaseCompletionPending"
            )
            manualAsrButtonPressed = false
            pendingManualAsrFinalTranscript = null
            voiceDuplexCoordinator.cancelManualReleaseLateFinal(
                reason = "manual_asr_press_new_session",
                closeSocket = true
            )
            internalUiState.update {
                it.copy(
                    voiceConnecting = false,
                    listening = false,
                    apiAsrListening = false,
                    manualAsrFinalizing = false,
                    apiAsrPartialText = null,
                    liveUserTranscript = null
                )
            }
        }
        val state = internalUiState.value
        val ttsPlaying = localTtsPlaying || state.localTtsSpeaking || state.apiTtsPlaying
        val clearCallResult = shouldClearCallResultForContinuation(
            state.taskStatus,
            state.agentCallResult
        )
        internalLog(
            "MANUAL_ASR start requested source=bottom_press " +
                "ttsPlaying=$ttsPlaying listening=${state.listening} apiAsrListening=${state.apiAsrListening} " +
                "voiceConnecting=${state.voiceConnecting} processingTurn=${state.processingTurn} " +
                "clearCallResult=$clearCallResult"
        )
        if (isOutboundCallAudioSuppressed()) {
            internalLog("MANUAL_ASR blocked reason=call_audio_suppressed source=bottom_press")
            voiceDuplexCoordinator.suspendDialogAudioForCall("manual_asr_press_call_active")
            return
        }
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            internalLog("MANUAL_ASR blocked reason=missing_record_audio_permission source=bottom_press")
            startApiListening(VoiceListenTriggers.ManualAsrPress)
            return
        }
        if (state.showAiCallPage || (!clearCallResult && (state.summary != null || state.selectionSheet != null))) {
            internalLog(
                "MANUAL_ASR blocked reason=ui_state_intercept source=bottom_press " +
                    "showAiCallPage=${state.showAiCallPage} summary=${state.summary != null} " +
                    "selectionSheet=${state.selectionSheet != null}"
            )
            return
        }
        if (clearCallResult) {
            ttsBridge.interrupt()
            assistantSpeechPlayer.stop()
            localTtsPlaying = false
            internalLog("MANUAL_ASR clearing terminal call result UI before continuation")
        }
        if (!ttsPlaying && (state.processingTurn || state.apiAsrListening || state.listening || state.voiceConnecting ||
                voiceDuplexCoordinator.dialogAsrActive)
        ) {
            internalLog(
                "MANUAL_ASR blocked reason=session_already_active source=bottom_press " +
                    "dialogAsrActive=${voiceDuplexCoordinator.dialogAsrActive}"
            )
            return
        }
        if (ttsPlaying) {
            internalLog(
                "MANUAL_ASR interrupt_tts reason=${TaskVoiceCloseReason.ManualTtsInterrupt.logKey} " +
                    "source=bottom_press apiTtsPlaying=${state.apiTtsPlaying} " +
                    "localTtsSpeaking=${state.localTtsSpeaking} localTtsPlaying=$localTtsPlaying"
            )
            ttsBridge.interrupt()
            agentStreamHandler.interruptCurrentStream()
            assistantSpeechPlayer.stop()
            closeTaskVoiceRealtime("manual_asr_press_interrupt_tts")
            localTtsPlaying = false
        }
        voiceRuntimeHandler.recordManualAsrPress(ttsPlaying = ttsPlaying, source = "bottom_press")
        manualAsrButtonPressed = true
        val recoverableBaseText = voiceRecoverableTurnCoordinator.recoverableBaseText()
        pendingManualAsrFinalTranscript = recoverableBaseText
        internalUiState.update {
            val baseState = if (clearCallResult) {
                AssistantUiStateReducer.clearCallResultUiForContinuation(it)
            } else {
                it
            }
            baseState.copy(
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceConnecting = true,
                voiceActive = false,
                listening = false,
                processingTurn = false,
                apiAsrListening = false,
                manualAsrFinalizing = false,
                apiAsrPartialText = recoverableBaseText,
                apiTtsPlaying = if (ttsPlaying || clearCallResult) false else it.apiTtsPlaying,
                localTtsSpeaking = if (ttsPlaying || clearCallResult) false else it.localTtsSpeaking,
                liveUserTranscript = recoverableBaseText,
                liveAssistantTranscript = if (ttsPlaying || clearCallResult) null else it.liveAssistantTranscript,
                error = null,
                status = localizedConnectingVoiceStatus()
            )
        }
        voiceRuntimeHandler.startManualAsrSessionTimeout("bottom_press")
        startApiListening(VoiceListenTriggers.ManualAsrPress)
    } }

    fun onManualAsrRelease() { with(viewModel) {
        if (internalUiState.value.manualAsrFinalizing) {
            internalLog("MANUAL_ASR release ignored reason=already_finalizing")
            return@with
        }
        autoResumeListeningJob?.cancel()
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        val state = internalUiState.value
        val releaseGeneration = manualAsrPressGeneration
        val bufferedFinalTranscript = pendingManualAsrFinalTranscript?.trim().orEmpty()
        voiceRuntimeHandler.cancelManualAsrSessionTimeout("manual_asr_release")
        if (state.processingTurn && bufferedFinalTranscript.isBlank()) {
            manualAsrButtonPressed = false
            internalUiState.update { it.copy(manualAsrFinalizing = false) }
            internalLog("MANUAL_ASR release ignored reason=processing_turn")
            return
        }
        val asrActive = state.apiAsrListening || state.listening || state.voiceConnecting ||
            voiceDuplexCoordinator.dialogAsrActive
        if (!asrActive) {
            manualAsrButtonPressed = false
            pendingManualAsrFinalTranscript = null
            val fallbackTranscript = (
                state.apiAsrPartialText?.trim()?.takeIf { it.isNotBlank() }
                    ?: state.liveUserTranscript?.trim().orEmpty()
                ).trim()
            val releaseSubmitTranscript = resolveManualAsrReleaseTranscript(
                bufferedFinal = bufferedFinalTranscript,
                fallback = fallbackTranscript
            ).text
            internalUiState.update {
                it.copy(
                    voiceManuallyPaused = false,
                    voiceBackgroundPaused = false,
                    voiceActive = true,
                    voiceConnecting = false,
                    listening = false,
                    apiAsrListening = false,
                    manualAsrFinalizing = false,
                    apiAsrPartialText = null,
                    liveUserTranscript = null,
                    error = null,
                    status = localizedTapMicToContinueStatus()
                )
            }
            if (releaseSubmitTranscript.isNotBlank()) {
                voiceRuntimeHandler.recordManualReleaseSubmit(releaseSubmitTranscript, "bottom_release_no_capture")
                enqueueRecognizedTurn(releaseSubmitTranscript)
            } else {
                voiceRuntimeHandler.recordManualReleaseNoTranscript("bottom_release_no_capture")
                internalUiState.update { it.copy(status = localizedNoValidSpeechStatus()) }
            }
            return
        }
        manualAsrButtonPressed = false
        internalUiState.update {
            it.copy(
                manualAsrFinalizing = true,
                status = localizedListeningStatus()
            )
        }
        internalLog(
            "MANUAL_ASR release finalizing armed maxCaptureMs=$ManualAsrFinalizeMaxCaptureMillis " +
                "generation=$releaseGeneration taskId=${state.taskId.orEmpty()}"
        )
        manualAsrReleaseFallbackJob = viewModelScope.launch {
            delay(ManualAsrFinalizeMaxCaptureMillis)
            if (manualAsrPressGeneration != releaseGeneration) {
                internalLog("MANUAL_ASR release finalizing skipped reason=new_manual_session")
                return@launch
            }
            val tailState = internalUiState.value
            val tailBufferedFinal = pendingManualAsrFinalTranscript?.trim().orEmpty()
            val tailFallbackTranscript = (
                tailState.apiAsrPartialText?.trim()?.takeIf { it.isNotBlank() }
                    ?: tailState.liveUserTranscript?.trim().orEmpty()
                ).trim()
            val releaseSubmitTranscript = resolveManualAsrReleaseTranscript(
                bufferedFinal = tailBufferedFinal,
                fallback = tailFallbackTranscript
            ).text
            val captureStillActive = tailState.apiAsrListening || tailState.listening ||
                tailState.voiceConnecting || voiceDuplexCoordinator.dialogAsrActive
            internalLog(
                "MANUAL_ASR release finalizing capture_deadline generation=$releaseGeneration " +
                    "captureActive=$captureStillActive bufferedFinal=${previewText(tailBufferedFinal)} " +
                    "fallback=${previewText(tailFallbackTranscript)}"
            )
            stopApiListening(preserveLateFinalGrace = false)
            taskAsrClient.closeNow("manual_release_capture_deadline")
            manualAsrReleaseFallbackJob = null
            pendingManualAsrFinalTranscript = null
            internalUiState.update {
                it.copy(
                    voiceManuallyPaused = false,
                    voiceBackgroundPaused = false,
                    voiceActive = true,
                    voiceConnecting = false,
                    listening = false,
                    apiAsrListening = false,
                    manualAsrFinalizing = false,
                    apiAsrPartialText = null,
                    liveUserTranscript = null,
                    error = null,
                    status = localizedTapMicToContinueStatus()
                )
            }
            val deadlineTranscript = releaseSubmitTranscript
                .takeUnless { it.isBlank() || looksLikeAsrMetadata(it) }
                .orEmpty()
            if (deadlineTranscript.isBlank()) {
                internalLog("MANUAL_ASR release capture_deadline reason=no_transcript")
                voiceRuntimeHandler.recordManualReleaseNoTranscript("manual_release_capture_deadline")
                internalUiState.update { it.copy(status = localizedNoValidSpeechStatus()) }
                return@launch
            }
            if (voiceRecognizedInputDedupTracker.isDuplicateInCurrentInput(deadlineTranscript)) {
                internalLog(
                    "MANUAL_ASR release capture_deadline skipped reason=already_committed " +
                        "generation=${voiceRecognizedInputDedupTracker.currentGeneration()} " +
                        "text=${previewText(deadlineTranscript)}"
                )
                return@launch
            }
            internalLog("MANUAL_ASR release capture_deadline submit text=${previewText(deadlineTranscript)}")
            voiceRuntimeHandler.recordManualReleaseSubmit(deadlineTranscript, "manual_release_capture_deadline")
            enqueueRecognizedTurn(deadlineTranscript)
        }
    } }

    fun onManualAsrCancel() {
        finishManualAsrWithoutSubmit(
            reason = "manual_asr_cancel",
            status = viewModel.localizedTapMicToContinueStatus(),
            recordNoTranscript = false
        )
    }

    fun onManualAsrTooShort() {
        finishManualAsrWithoutSubmit(
            reason = "manual_asr_too_short",
            status = viewModel.localizedNoValidSpeechStatus(),
            recordNoTranscript = true
        )
    }

    private fun finishManualAsrWithoutSubmit(
        reason: String,
        status: String,
        recordNoTranscript: Boolean
    ) { with(viewModel) {
        autoResumeListeningJob?.cancel()
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        val state = internalUiState.value
        internalLog(
            "MANUAL_ASR stop_without_submit reason=$reason " +
                "listening=${state.listening} apiAsrListening=${state.apiAsrListening} " +
                "voiceConnecting=${state.voiceConnecting} dialogAsrActive=${voiceDuplexCoordinator.dialogAsrActive}"
        )
        voiceRuntimeHandler.cancelManualAsrSessionTimeout(reason)
        manualAsrButtonPressed = false
        pendingManualAsrFinalTranscript = null
        val asrActive = state.apiAsrListening || state.listening || state.voiceConnecting ||
            voiceDuplexCoordinator.dialogAsrActive
        if (asrActive) {
            stopApiListening(preserveLateFinalGrace = false)
        }
        voiceDuplexCoordinator.cancelManualReleaseLateFinal(reason, closeSocket = true)
        internalUiState.update {
            it.copy(
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceActive = true,
                voiceConnecting = false,
                listening = false,
                apiAsrListening = false,
                manualAsrFinalizing = false,
                apiAsrPartialText = null,
                liveUserTranscript = null,
                error = null,
                status = status
            )
        }
        if (recordNoTranscript) {
            voiceRuntimeHandler.recordManualReleaseNoTranscript(reason)
        }
    } }

    fun onTtsInterrupted() { with(viewModel) {
        autoResumeListeningJob?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        internalLog(
            "TTS_CONTROL interrupt_tts reason=${TaskVoiceCloseReason.ManualTtsInterrupt.logKey} source=explicit_control " +
                "apiTtsPlaying=${internalUiState.value.apiTtsPlaying} " +
                "localTtsSpeaking=${internalUiState.value.localTtsSpeaking} localTtsPlaying=$localTtsPlaying"
        )
        ttsBridge.interrupt()
        agentStreamHandler.interruptCurrentStream()
        assistantSpeechPlayer.stop()
        localTtsPlaying = false
        voiceRuntimeHandler.recordManualTtsInterrupt("explicit_control", startAsrAfter = false)
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("tts_interrupted_call_active")
            return
        }
        closeTaskVoiceRealtime("tts_paused_by_user")
        val pauseFlags = voicePauseFlagsFor(VoicePauseSource.User)
        internalUiState.update {
            it.copy(
                voiceManuallyPaused = pauseFlags.manuallyPaused,
                voiceBackgroundPaused = pauseFlags.backgroundPaused,
                voiceActive = true,
                listening = false,
                voiceConnecting = false,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                liveAssistantTranscript = null,
                error = null,
                status = localizedPausedTapToContinueStatus()
            )
        }
    } }
}
