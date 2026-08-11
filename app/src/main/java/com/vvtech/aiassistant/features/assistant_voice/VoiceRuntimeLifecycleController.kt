package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import android.content.Context
import android.media.AudioManager
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.LiveSpeechTranscriptionSocketClient
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultUserId
import kotlinx.coroutines.flow.update

internal interface VoiceRuntimeLifecycleCallbacks {
    fun recordVoiceTurnClosed(reason: TaskVoiceCloseReason, source: String)
    fun cancelAsrInputWatchdogs(reason: String)
    fun cancelManualAsrSessionTimeout(reason: String)
    fun startAsrInputWatchdog(source: String)
    fun resetRecognizedTurnDedup()
    fun activeVoiceTaskId(): String?
    fun handleLiveTranscriptionEvent(
        captureGeneration: Long,
        event: LiveSpeechTranscriptionSocketClient.Event
    )
}

internal class VoiceRuntimeLifecycleController(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceRuntimeLifecycleCallbacks
) {
    fun stopVoiceInteraction(reason: String = "stop_voice_interaction") { with(viewModel) {
        voiceRecoverableTurnCoordinator.clear(reason)
        callbacks.recordVoiceTurnClosed(TaskVoiceCloseReason.LifecycleCancel, reason)
        callbacks.cancelAsrInputWatchdogs(reason)
        callbacks.cancelManualAsrSessionTimeout(reason)
        autoResumeListeningJob?.cancel()
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        manualAsrButtonPressed = false
        pendingManualAsrFinalTranscript = null
        pendingDialogTargetScene = null
        pendingCarryoverScene = null
        pendingCarryoverUtterance = null
        pendingSyntheticAssistantPrompt = null
        pendingAutoListenAfterSelectionPrompt = false
        suppressAssistantEventsForCurrentRun = false
        voiceDuplexCoordinator.reset()
        restoreNormalAudioMode()
        internalLog(
            "stopVoiceInteraction reason=$reason runId=$activeDialogRunId " +
                "scene=${activeDialogContext?.sceneType} dialogKey=${activeDialogContext?.dialogKey}"
        )
        stopRealtimeSession()
        ttsBridge.closeRealtime(reason)
        agentStreamHandler.interruptCurrentStream()
        if (audioRecorder.isRecording()) audioRecorder.stop()
        taskAsrClient.closeNow(reason)
        activeDialogContext = null
        queuedRecognizedTurns.clear()
        callbacks.resetRecognizedTurnDedup()
        pendingStructuredRecognizedTurn = null
        latestRealtimeAssistantReplyForBackend = null
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
    } }

    fun stopRealtimeSession() { with(viewModel) {
        callbacks.recordVoiceTurnClosed(TaskVoiceCloseReason.LifecycleCancel, "stop_realtime_session")
        callbacks.cancelAsrInputWatchdogs("stop_realtime_session")
        callbacks.cancelManualAsrSessionTimeout("stop_realtime_session")
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        manualAsrButtonPressed = false
        pendingManualAsrFinalTranscript = null
        internalUiState.update { it.copy(manualAsrFinalizing = false) }
        internalLog(
            "stopRealtimeSession runId=$activeDialogRunId scene=${activeDialogContext?.sceneType} " +
                "dialogKey=${activeDialogContext?.dialogKey}"
        )
        suppressAutoRestartOnClose = true
        localTtsPlaying = false
        voiceDuplexCoordinator.reset()
        assistantSpeechPlayer.stop()
        taskAsrClient.closeNow("stop_realtime_session")
        liveSpeechClient.release()
        speechRecognizer.release()
        backendSpeechFallbackActive = false
        platformSpeechFallbackStarted = false
    } }

    fun closeTaskVoiceRealtime(reason: String) { with(viewModel) {
        internalLog("closeTaskVoiceRealtime reason=$reason")
        autoResumeListeningJob?.cancel()
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        manualAsrButtonPressed = false
        pendingManualAsrFinalTranscript = null
        internalUiState.update { it.copy(manualAsrFinalizing = false) }
        voiceDuplexCoordinator.reset()
        if (audioRecorder.isRecording()) {
            audioRecorder.stop()
        }
        taskAsrClient.closeNow(reason)
        liveSpeechClient.stop()
        speechRecognizer.stop()
        ttsBridge.closeRealtime(reason)
        assistantSpeechPlayer.stop()
        localTtsPlaying = false
        backendSpeechFallbackActive = false
        platformSpeechFallbackStarted = false
        restoreNormalAudioMode()
    } }

    fun resumeListeningAfterTts() { with(viewModel) {
        localTtsPlaying = false
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("resume_listening_after_tts_call_active")
            return
        }
        internalLog("resumeListeningAfterTts: manual ASR gate keeps session paused")
        internalUiState.update {
            it.copy(
                localTtsSpeaking = false,
                liveAssistantTranscript = null,
                listening = false,
                voiceConnecting = false,
                apiAsrListening = false,
                apiAsrPartialText = null
            )
        }
        voiceDuplexCoordinator.markPausedIfVoiceCanContinue("resume_listening_after_tts_manual_gate")
    } }

    fun startBackendSpeechFallback() { with(viewModel) {
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("backend_speech_fallback_call_active")
            return
        }
        if (backendSpeechFallbackActive) return
        backendSpeechFallbackActive = true
        platformSpeechFallbackStarted = false
        val taskId = callbacks.activeVoiceTaskId()
        internalLog("startBackendSpeechFallback language=$voiceLanguageCode taskId=$taskId")
        liveSpeechClient.stop()
        speechRecognizer.stop()
        backendSpeechFallbackGeneration += 1
        val captureGeneration = backendSpeechFallbackGeneration
        callbacks.startAsrInputWatchdog("backend_fallback")
        liveSpeechClient.start(
            DefaultUserId,
            taskId,
            voiceLanguageCode,
            onEvent = { event -> callbacks.handleLiveTranscriptionEvent(captureGeneration, event) }
        )
    } }

    fun pauseVoiceAfterBackendSpeechFallbackFailure(reason: String) { with(viewModel) {
        internalLog("VOICE_TASK_ASR backend fallback failed; platform speech fallback disabled reason=$reason")
        backendSpeechFallbackActive = false
        platformSpeechFallbackStarted = false
        liveSpeechClient.stop()
        speechRecognizer.stop()
        callbacks.cancelAsrInputWatchdogs(reason)
        applyNetworkTaskErrorState(reason)
    } }

    private fun AssistantViewModel.restoreNormalAudioMode() {
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_NORMAL
    }
}
