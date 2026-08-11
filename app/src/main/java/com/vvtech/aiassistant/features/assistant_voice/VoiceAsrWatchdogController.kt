package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.localizedConfirmingDetailsStatus
import com.vvtech.aiassistant.features.assistant.localizedPausedTapToContinueStatus
import com.vvtech.aiassistant.features.assistant.localizedRealtimeFallbackStatus
import com.vvtech.aiassistant.features.assistant.localizedTapMicToContinueStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.maxStage
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.replaceChineseDigits
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
internal class VoiceAsrWatchdogController(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceAsrWatchdogCallbacks
) {
    private var asrWatchdogGeneration = 0
    private var asrNoEventWatchdogJob: Job? = null
    private var asrPartialCommitJob: Job? = null
    private var asrIdleWatchdogJob: Job? = null
    private var manualAsrTimeoutGeneration = 0
    private var manualAsrTimeoutJob: Job? = null
    private var latestAsrPartialText = ""
    fun startAsrInputWatchdog(source: String) { with(viewModel) {
        val generation = ++asrWatchdogGeneration
        latestAsrPartialText = ""
        asrNoEventWatchdogJob?.cancel()
        asrPartialCommitJob?.cancel()
        asrIdleWatchdogJob?.cancel()
        internalLog(
            "ASR_WATCHDOG start source=$source generation=$generation " +
                "voiceConnecting=${internalUiState.value.voiceConnecting} " +
                "voiceActive=${internalUiState.value.voiceActive} listening=${internalUiState.value.listening}"
        )
        asrNoEventWatchdogJob = viewModelScope.launch {
            delay(ASR_NO_EVENT_TIMEOUT_MS)
            handleAsrNoEventTimeout(generation, source)
        }
        scheduleAsrIdleTimeout(generation, source)
    } }

    fun markAsrReady(source: String) { with(viewModel) {
        if (asrWatchdogGeneration == 0) {
            startAsrInputWatchdog(source)
        }
        asrNoEventWatchdogJob?.cancel()
        callbacks.onAsrReady(source)
        internalLog("ASR_WATCHDOG ready source=$source generation=$asrWatchdogGeneration")
        scheduleAsrIdleTimeout(asrWatchdogGeneration, source)
    } }

    fun markAsrPartial(text: String, source: String) { with(viewModel) {
        val normalized = replaceChineseDigits(text.trim())
        if (normalized.isBlank() || looksLikeAsrMetadata(normalized)) {
            return
        }
        if (asrWatchdogGeneration == 0) {
            startAsrInputWatchdog(source)
        }
        val generation = asrWatchdogGeneration
        latestAsrPartialText = normalized
        asrNoEventWatchdogJob?.cancel()
        callbacks.onAsrPartial(normalized, source)
        scheduleAsrIdleTimeout(generation, source)
        asrPartialCommitJob?.cancel()
        internalLog(
            "ASR_WATCHDOG partial source=$source generation=$generation " +
                "text=${previewText(normalized)}"
        )
        if (manualAsrButtonPressed) {
            internalLog(
                "ASR_WATCHDOG partial_commit_suppressed reason=manual_ptt " +
                    "source=$source generation=$generation"
            )
            return@with
        }
        asrPartialCommitJob = viewModelScope.launch {
            delay(ASR_PARTIAL_COMMIT_TIMEOUT_MS)
            commitLatestAsrPartialIfStale(generation, source, normalized)
        }
    } }

    fun markAsrFinal(source: String) {
        cancelManualAsrSessionTimeout("final_$source")
        cancelAsrInputWatchdogs("final_$source")
    }

    fun markAsrError(source: String) {
        callbacks.onProviderError(source)
        cancelManualAsrSessionTimeout("error_$source")
        cancelAsrInputWatchdogs("error_$source")
    }

    fun markAsrClosed(source: String) {
        callbacks.onProviderClosed(source)
        cancelManualAsrSessionTimeout("closed_$source")
        cancelAsrInputWatchdogs("closed_$source")
    }

    fun cancelAsrInputWatchdogs(reason: String) { with(viewModel) {
        asrWatchdogGeneration++
        asrNoEventWatchdogJob?.cancel()
        asrPartialCommitJob?.cancel()
        asrIdleWatchdogJob?.cancel()
        asrNoEventWatchdogJob = null
        asrPartialCommitJob = null
        asrIdleWatchdogJob = null
        latestAsrPartialText = ""
        internalLog("ASR_WATCHDOG cancel reason=$reason generation=$asrWatchdogGeneration")
    } }

    fun startManualAsrSessionTimeout(source: String) { with(viewModel) {
        val generation = ++manualAsrTimeoutGeneration
        manualAsrTimeoutJob?.cancel()
        internalLog(
            "MANUAL_ASR timeout_start source=$source generation=$generation maxMs=$ASR_IDLE_TIMEOUT_MS"
        )
        manualAsrTimeoutJob = viewModelScope.launch {
            delay(ASR_IDLE_TIMEOUT_MS)
            handleManualAsrTimeout(generation, source)
        }
    } }

    fun cancelManualAsrSessionTimeout(reason: String) { with(viewModel) {
        manualAsrTimeoutGeneration++
        manualAsrTimeoutJob?.cancel()
        manualAsrTimeoutJob = null
        internalLog(
            "MANUAL_ASR timeout_cancel reason=$reason generation=$manualAsrTimeoutGeneration"
        )
    } }

    fun shouldDropDuplicateRecognizedText(text: String, source: String): Boolean = with(viewModel) {
        if (internalUiState.value.agentDeviceContactSelection != null) {
            return@with false
        }
        val normalized = replaceChineseDigits(text.trim())
        if (normalized.isBlank()) {
            return@with false
        }
        val duplicate = voiceRecognizedInputDedupTracker.isDuplicateInCurrentInput(normalized)
        if (duplicate) {
            internalLog(
                "ASR_WATCHDOG duplicate_final_dropped source=$source " +
                    "generation=${voiceRecognizedInputDedupTracker.currentGeneration()} " +
                    "text=${previewText(normalized)}"
            )
            cancelAsrInputWatchdogs("duplicate_final_$source")
            voiceDuplexCoordinator.restartListeningAfterDroppedTranscript("duplicate_final_$source")
        }
        duplicate
    }

    private fun scheduleAsrIdleTimeout(generation: Int, source: String) { with(viewModel) {
        asrIdleWatchdogJob?.cancel()
        asrIdleWatchdogJob = viewModelScope.launch {
            delay(ASR_IDLE_TIMEOUT_MS)
            handleAsrIdleTimeout(generation, source)
        }
    } }

    private fun handleAsrNoEventTimeout(generation: Int, source: String) { with(viewModel) {
        if (generation != asrWatchdogGeneration) return@with
        val state = internalUiState.value
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("asr_no_event_timeout_call_active")
            return@with
        }
        if (state.processingTurn || state.voiceManuallyPaused || state.showAiCallPage ||
            state.summary != null || state.selectionSheet != null
        ) return@with
        internalLog(
            "ASR_WATCHDOG no_event_timeout source=$source generation=$generation " +
                "backendFallback=$backendSpeechFallbackActive speechFallbackStarted=$speechFallbackStarted"
        )
        if (!backendSpeechFallbackActive && !speechFallbackStarted) {
            speechFallbackStarted = true
            internalUiState.update {
                it.copy(
                    voiceConnecting = false,
                    listening = false,
                    apiAsrListening = false,
                    apiAsrPartialText = null,
                    error = null,
                    status = localizedRealtimeFallbackStatus()
                )
            }
            callbacks.startBackendSpeechFallback()
            return@with
        }
        stopAsrForWatchdog("no_event_timeout_$source")
        cancelAsrInputWatchdogs("no_event_timeout_$source")
        internalUiState.update { it.pausedAfterAsrWatchdog(localizedPausedTapToContinueStatus()) }
    } }

    private fun handleAsrIdleTimeout(generation: Int, source: String) { with(viewModel) {
        if (generation != asrWatchdogGeneration) return@with
        val state = internalUiState.value
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("asr_idle_timeout_call_active")
            return@with
        }
        if (state.processingTurn || state.voiceManuallyPaused || state.showAiCallPage ||
            state.summary != null || state.selectionSheet != null
        ) return@with
        if (!state.listening && !state.apiAsrListening && !state.voiceConnecting) {
            return@with
        }
        internalLog(
            "ASR_WATCHDOG idle_timeout source=$source generation=$generation " +
                "latestPartial=${previewText(latestAsrPartialText)}"
        )
        stopAsrForWatchdog("idle_timeout_$source")
        cancelAsrInputWatchdogs("idle_timeout_$source")
        internalUiState.update { it.pausedAfterAsrWatchdog(localizedPausedTapToContinueStatus()) }
    } }

    private fun handleManualAsrTimeout(generation: Int, source: String) { with(viewModel) {
        if (generation != manualAsrTimeoutGeneration) return@with
        val state = internalUiState.value
        val bufferedFinalTranscript = pendingManualAsrFinalTranscript?.trim().orEmpty()
        val hasManualHoldState = manualAsrButtonPressed || bufferedFinalTranscript.isNotBlank()
        if (!state.listening && !state.apiAsrListening && !state.voiceConnecting &&
            !voiceDuplexCoordinator.dialogAsrActive && !hasManualHoldState
        ) return@with
        internalLog(
            "MANUAL_ASR stop reason=manual_asr_timeout_60s source=$source generation=$generation " +
                "listening=${state.listening} apiAsrListening=${state.apiAsrListening} " +
                "voiceConnecting=${state.voiceConnecting} manualHold=$manualAsrButtonPressed " +
                "bufferedFinal=${previewText(bufferedFinalTranscript)}"
        )
        val fallbackTranscript = (
            state.apiAsrPartialText?.trim()?.takeIf { it.isNotBlank() }
                ?: state.liveUserTranscript?.trim()?.takeIf { it.isNotBlank() }
                ?: latestAsrPartialText.trim()
            ).trim()
        val fallbackExtendsBufferedFinal = bufferedFinalTranscript.isNotBlank() &&
            fallbackTranscript.length > bufferedFinalTranscript.length &&
            fallbackTranscript.contains(bufferedFinalTranscript)
        val autoSubmitCandidate = when {
            fallbackExtendsBufferedFinal -> fallbackTranscript
            bufferedFinalTranscript.isNotBlank() -> bufferedFinalTranscript
            else -> fallbackTranscript
        }
        val autoSubmitText = autoSubmitCandidate
            .takeUnless { it.isBlank() || looksLikeAsrMetadata(it) }
            .orEmpty()
        callbacks.onManualAsrTimeout(source)
        manualAsrButtonPressed = false
        pendingManualAsrFinalTranscript = null
        stopAsrForWatchdog("manual_asr_timeout_60s")
        cancelAsrInputWatchdogs("manual_asr_timeout_60s")
        cancelManualAsrSessionTimeout("manual_asr_timeout_60s")
        if (autoSubmitText.isNotBlank()) {
            internalLog(
                "MANUAL_ASR timeout auto_submit text=${previewText(autoSubmitText)}"
            )
            voiceRuntimeHandler.recordManualReleaseSubmit(autoSubmitText, "manual_asr_timeout_60s")
            enqueueRecognizedTurn(autoSubmitText)
            return@with
        }
        internalUiState.update {
            it.copy(
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceActive = true,
                voiceConnecting = false,
                listening = false,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                liveUserTranscript = null,
                status = localizedNoValidSpeechStatus()
            )
        }
    } }

    private fun commitLatestAsrPartialIfStale(generation: Int, source: String, expectedText: String) { with(viewModel) {
        if (generation != asrWatchdogGeneration || latestAsrPartialText != expectedText) return@with
        val state = internalUiState.value
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("asr_partial_commit_call_active")
            return@with
        }
        if (state.processingTurn || state.voiceManuallyPaused || state.showAiCallPage ||
            state.summary != null || state.selectionSheet != null
        ) return@with
        val normalized = replaceChineseDigits(expectedText.trim())
        if (normalized.isBlank() || looksLikeAsrMetadata(normalized)) return@with
        internalLog(
            "ASR_WATCHDOG partial_commit_timeout source=$source generation=$generation " +
                "text=${previewText(normalized)}"
        )
        stopAsrForWatchdog("partial_commit_$source")
        cancelAsrInputWatchdogs("partial_commit_$source")
        val appendUserStep = normalized != lastCommittedUserTranscript
        internalUiState.update {
            it.copy(
                stage = maxStage(it.stage, AssistantStage.Clarifying),
                voiceConnecting = false,
                voiceActive = true,
                voiceManuallyPaused = false,
                listening = false,
                processingTurn = true,
                apiAsrListening = false,
                apiAsrPartialText = null,
                error = null,
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                status = localizedConfirmingDetailsStatus(activeDialogContext?.sceneType ?: it.sceneType)
            )
        }
        submitVoiceSupplementTask(normalized, appendUserStep = appendUserStep)
    } }

    private fun stopAsrForWatchdog(reason: String) { with(viewModel) {
        internalLog(
            "ASR_WATCHDOG stop_asr reason=$reason " +
                "dialogAsrActive=${voiceDuplexCoordinator.dialogAsrActive} backendFallback=$backendSpeechFallbackActive"
        )
        cancelManualAsrSessionTimeout(reason)
        suppressAutoRestartOnClose = true
        voiceDuplexCoordinator.dialogAsrActive = false
        backendSpeechFallbackActive = false
        platformSpeechFallbackStarted = false
        taskAsrClient.closeNow(reason)
        liveSpeechClient.stop()
        speechRecognizer.stop()
    } }

}
