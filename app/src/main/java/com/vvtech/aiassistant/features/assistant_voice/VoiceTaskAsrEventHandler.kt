package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.TaskVoiceAsrEvent
import com.vvtech.aiassistant.features.assistant.localizedListeningStatus
import com.vvtech.aiassistant.features.assistant.localizedRealtimeFallbackStatus
import com.vvtech.aiassistant.features.assistant.shouldHoldVoiceAfterPromptPlayback
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.flow.update

internal interface VoiceTaskAsrEventCallbacks {
    var dialogAsrActive: Boolean
    var awaitingManualReleaseFinal: Boolean
    fun suspendDialogAudioForCall(reason: String)
    fun ignoreDuringSimplexPlayback(eventName: String): Boolean
    fun restoreNormalAudioMode()
    fun pauseAfterRealtimeFailure(reason: String, closeTts: Boolean, closeAsr: Boolean)
}

internal class VoiceTaskAsrEventHandler(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceTaskAsrEventCallbacks
) {
    fun handle(event: TaskVoiceAsrEvent) { with(viewModel) {
        if (isOutboundCallAudioSuppressed()) {
            callbacks.suspendDialogAudioForCall("dialog_asr_event_${event.javaClass.simpleName}")
            return
        }
        if (event is TaskVoiceAsrEvent.PartialTranscript ||
            event is TaskVoiceAsrEvent.FinalTranscript ||
            event is TaskVoiceAsrEvent.Ready
        ) {
            if (callbacks.ignoreDuringSimplexPlayback(event.javaClass.simpleName)) {
                return
            }
        }
        when (event) {
            is TaskVoiceAsrEvent.PartialTranscript -> handlePartial(event)
            is TaskVoiceAsrEvent.FinalTranscript -> handleFinal(event)
            is TaskVoiceAsrEvent.Error -> handleError(event)
            is TaskVoiceAsrEvent.Closed -> handleClosed(event)
            is TaskVoiceAsrEvent.Ready -> handleReady()
            else -> Unit
        }
    } }

    private fun handlePartial(event: TaskVoiceAsrEvent.PartialTranscript) { with(viewModel) {
        if (!callbacks.dialogAsrActive) return
        if (callbacks.awaitingManualReleaseFinal) {
            internalLog(
                "VOICE_DUPLEX dialog ASR partial ignored reason=late_partial_after_release " +
                    "text=${previewText(event.text)}"
            )
            return
        }
        val partialText = event.text.trim()
        if (partialText.isBlank()) return
        val releaseFinalizing = internalUiState.value.manualAsrFinalizing
        val displayText = mergeManualAsrTranscript(
            prefix = pendingManualAsrFinalTranscript?.takeIf {
                manualAsrButtonPressed || releaseFinalizing
            } ?: voiceRecoverableTurnCoordinator.recoverableBaseText(),
            next = partialText
        )
        voiceRuntimeHandler.markAsrPartial(displayText, "dialog_asr")
        internalUiState.update {
            it.copy(
                apiAsrPartialText = displayText,
                liveUserTranscript = displayText
            )
        }
    } }

    private fun handleFinal(event: TaskVoiceAsrEvent.FinalTranscript) { with(viewModel) {
        if (!callbacks.dialogAsrActive && !callbacks.awaitingManualReleaseFinal) return
        val releaseFinalizing = internalUiState.value.manualAsrFinalizing
        val lateAfterRelease = callbacks.awaitingManualReleaseFinal || releaseFinalizing
        internalLog(
            "VOICE_DUPLEX dialog ASR final: ${previewText(event.text)} " +
                "lateAfterRelease=$lateAfterRelease releaseFinalizing=$releaseFinalizing"
        )
        val finalText = event.text.trim()
        val validFinalText = finalText.isNotBlank() && !looksLikeAsrMetadata(finalText)
        if (releaseFinalizing && !validFinalText) {
            if (finalText.isNotBlank()) {
                AppFileLogger.w(
                    "VoiceTaskAsrEventHandler",
                    "ASR dialog transcript filtered while finalizing (SDK metadata): $finalText"
                )
            }
            internalLog(
                "VOICE_DUPLEX dialog ASR final ignored while finalizing reason=" +
                    if (finalText.isBlank()) "blank" else "metadata"
            )
            return
        }
        callbacks.awaitingManualReleaseFinal = false
        val keepManualSessionOpen = manualAsrButtonPressed && !lateAfterRelease
        val previousBufferedFinal = pendingManualAsrFinalTranscript?.trim().orEmpty()
        if (!keepManualSessionOpen && validFinalText) {
            manualAsrReleaseFallbackJob?.cancel()
            manualAsrReleaseFallbackJob = null
        }
        if (keepManualSessionOpen) {
            voiceRuntimeHandler.cancelAsrInputWatchdogs("final_buffered_dialog_asr")
        } else {
            voiceRuntimeHandler.markAsrFinal("dialog_asr")
            callbacks.dialogAsrActive = false
            callbacks.restoreNormalAudioMode()
            if (releaseFinalizing) {
                taskAsrClient.closeNow("manual_release_final_delivered")
            } else {
                taskAsrClient.stop()
            }
        }
        var bufferedFinalText: String? = null
        if (finalText.isNotBlank()) {
            if (looksLikeAsrMetadata(finalText)) {
                AppFileLogger.w(
                    "VoiceTaskAsrEventHandler",
                    "ASR dialog transcript filtered (SDK metadata): $finalText"
                )
            } else {
                val mergedFinalText = mergeManualAsrTranscript(
                    prefix = previousBufferedFinal.takeIf { keepManualSessionOpen || lateAfterRelease },
                    next = finalText
                )
                if (voiceRuntimeHandler.shouldDropDuplicateRecognizedText(mergedFinalText, "dialog_asr")) {
                    Unit
                } else if (keepManualSessionOpen) {
                    bufferedFinalText = mergedFinalText
                    pendingManualAsrFinalTranscript = mergedFinalText
                    voiceRuntimeHandler.recordAsrFinalBuffered(mergedFinalText, "dialog_asr")
                    internalLog(
                        "VOICE_DUPLEX dialog ASR final buffered awaiting_release " +
                            "text=${previewText(mergedFinalText)}"
                    )
                } else {
                    pendingManualAsrFinalTranscript = null
                    voiceRuntimeHandler.recordAgentSubmitting(mergedFinalText, "dialog_asr_final")
                    submitVoiceSupplementTask(mergedFinalText)
                }
            }
        } else if (!keepManualSessionOpen) {
            pendingManualAsrFinalTranscript = null
        }
        internalUiState.update {
            it.copy(
                apiAsrListening = if (keepManualSessionOpen) it.apiAsrListening else false,
                manualAsrFinalizing = if (!keepManualSessionOpen && validFinalText) {
                    false
                } else {
                    it.manualAsrFinalizing
                },
                apiAsrPartialText = bufferedFinalText ?: if (keepManualSessionOpen) it.apiAsrPartialText else null,
                apiTtsPlaying = false,
                liveUserTranscript = bufferedFinalText ?: if (keepManualSessionOpen) it.liveUserTranscript else null
            )
        }
    } }


    private fun handleError(event: TaskVoiceAsrEvent.Error) { with(viewModel) {
        if (!callbacks.dialogAsrActive) return
        voiceRuntimeHandler.markAsrError("dialog_asr")
        internalLog("VOICE_DUPLEX dialog ASR error reason=${TaskVoiceCloseReason.ProviderError.logKey}: ${event.message}")
        callbacks.dialogAsrActive = false
        callbacks.awaitingManualReleaseFinal = false
        callbacks.restoreNormalAudioMode()
        taskAsrClient.stop()
        if (internalUiState.value.agentCallResult != null) {
            clearAsrUi()
            return
        }
        if (!speechFallbackStarted) {
            speechFallbackStarted = true
            internalUiState.update {
                it.copy(
                    listening = false,
                    voiceConnecting = false,
                    apiAsrListening = false,
                    apiAsrPartialText = null,
                    error = null,
                    status = localizedRealtimeFallbackStatus()
                )
            }
            voiceRuntimeHandler.startBackendSpeechFallback()
            return
        }
        if (!internalUiState.value.apiTtsPlaying) {
            callbacks.pauseAfterRealtimeFailure(
                reason = "dialog_asr_error:${event.message}",
                closeTts = false,
                closeAsr = true
            )
        } else {
            clearAsrUi()
        }
    } }

    private fun handleClosed(event: TaskVoiceAsrEvent.Closed) { with(viewModel) {
        if (!callbacks.dialogAsrActive) return
        voiceRuntimeHandler.markAsrClosed("dialog_asr_closed")
        internalLog(
            "VOICE_DUPLEX dialog ASR closed reason=${event.reason.ifBlank { TaskVoiceCloseReason.ProviderClosed.logKey }} " +
                "ttsPlaying=${internalUiState.value.apiTtsPlaying}"
        )
        callbacks.dialogAsrActive = false
        callbacks.awaitingManualReleaseFinal = false
        callbacks.restoreNormalAudioMode()
        if (internalUiState.value.apiTtsPlaying) {
            clearAsrUi()
        } else {
            callbacks.pauseAfterRealtimeFailure(
                reason = "dialog_asr_closed",
                closeTts = false,
                closeAsr = false
            )
        }
    } }

    private fun handleReady() { with(viewModel) {
        if (!callbacks.dialogAsrActive) {
            internalLog(
                "VOICE_DUPLEX dialog SDK ready ignored reason=late_ready_after_release " +
                    "voiceConnecting=${internalUiState.value.voiceConnecting} " +
                    "apiAsrListening=${internalUiState.value.apiAsrListening}"
            )
            return
        }
        if (shouldHoldVoiceAfterPromptPlayback(
                internalUiState.value.voiceManuallyPaused,
                internalUiState.value.voiceBackgroundPaused
            )
        ) {
            internalLog("VOICE_DUPLEX dialog SDK ready ignored while paused")
            return
        }
        voiceRuntimeHandler.markAsrReady("dialog_asr")
        internalLog("VOICE_DUPLEX dialog SDK ready for ASR")
        internalUiState.update {
            val speaking = it.apiTtsPlaying || it.localTtsSpeaking
            it.copy(
                voiceConnecting = false,
                listening = !speaking,
                apiAsrListening = true,
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                status = localizedListeningStatus()
            )
        }
    } }

    private fun clearAsrUi() {
        if (viewModel.internalUiState.value.manualAsrFinalizing) {
            viewModel.manualAsrReleaseFallbackJob?.cancel()
            viewModel.manualAsrReleaseFallbackJob = null
            viewModel.pendingManualAsrFinalTranscript = null
        }
        viewModel.internalUiState.update {
            it.copy(
                listening = false,
                voiceConnecting = false,
                apiAsrListening = false,
                manualAsrFinalizing = false,
                apiAsrPartialText = null
            )
        }
    }
}
