package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.LiveSpeechTranscriptionSocketClient
import com.vvtech.aiassistant.features.assistant.SpeechRecognitionEvent
import com.vvtech.aiassistant.features.assistant.localizedConfirmingDetailsStatus
import com.vvtech.aiassistant.features.assistant.localizedListeningStatus
import com.vvtech.aiassistant.features.assistant.localizedRealtimeTranscriptionConnectingStatus
import com.vvtech.aiassistant.features.assistant.localizedVoiceRecoveryResumeStatus
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant.viewmodel.AutoResumeListeningDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.maxStage
import kotlinx.coroutines.flow.update

internal interface VoiceFallbackSpeechEventCallbacks {
    fun markAsrReady(source: String)
    fun markAsrPartial(text: String, source: String)
    fun markAsrFinal(source: String)
    fun markAsrError(source: String)
    fun markAsrClosed(source: String)
    fun recordAgentSubmitting(text: String, source: String)
    fun enqueueRecognizedTurn(text: String)
    fun pauseVoiceAfterBackendSpeechFallbackFailure(reason: String)
}

internal class VoiceFallbackSpeechEventHandler(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceFallbackSpeechEventCallbacks
) {
    fun handleLiveTranscriptionEvent(event: LiveSpeechTranscriptionSocketClient.Event) { with(viewModel) {
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("live_transcription_${event.javaClass.simpleName}")
            return
        }
        when (event) {
            LiveSpeechTranscriptionSocketClient.Event.Connected -> {
                backendSpeechFallbackActive = true
                callbacks.markAsrReady("backend_fallback_connected")
                internalUiState.update {
                    it.copy(
                        voiceManuallyPaused = false,
                        listening = true,
                        processingTurn = false,
                        status = localizedRealtimeTranscriptionConnectingStatus()
                    )
                }
            }

            LiveSpeechTranscriptionSocketClient.Event.Ready -> {
                backendSpeechFallbackActive = true
                callbacks.markAsrReady("backend_fallback")
                internalUiState.update {
                    it.copy(
                        listening = true,
                        processingTurn = false,
                        error = null,
                        status = localizedListeningStatus()
                    )
                }
            }

            is LiveSpeechTranscriptionSocketClient.Event.Status -> {
                backendSpeechFallbackActive = true
                if (internalUiState.value.listening && !internalUiState.value.processingTurn) {
                    internalUiState.update {
                        it.copy(status = sanitizeUserFacingNetworkText(event.message, currentVoiceLanguage()))
                    }
                }
            }

            is LiveSpeechTranscriptionSocketClient.Event.PartialTranscript -> {
                backendSpeechFallbackActive = true
                val displayText = mergeManualAsrTranscript(
                    prefix = pendingManualAsrFinalTranscript?.takeIf {
                        manualAsrButtonPressed || internalUiState.value.manualAsrFinalizing
                    },
                    next = event.text
                )
                callbacks.markAsrPartial(displayText, "backend_fallback")
                internalUiState.update {
                    it.copy(
                        stage = maxStage(it.stage, AssistantStage.Clarifying),
                        listening = true,
                        processingTurn = false,
                        error = null,
                        status = displayText,
                        liveUserTranscript = displayText
                    )
                }
            }

            is LiveSpeechTranscriptionSocketClient.Event.FinalTranscript -> {
                if (!backendSpeechFallbackActive &&
                    !manualAsrButtonPressed &&
                    !internalUiState.value.manualAsrFinalizing
                ) return@with
                if (consumeManualAsrFinal(event.text, "backend_fallback")) return@with
                backendSpeechFallbackActive = false
                liveSpeechClient.stop()
                callbacks.markAsrFinal("backend_fallback")
                callbacks.recordAgentSubmitting(event.text, "backend_fallback_final")
                callbacks.enqueueRecognizedTurn(event.text)
            }

            is LiveSpeechTranscriptionSocketClient.Event.Error -> {
                callbacks.markAsrError("backend_fallback")
                callbacks.pauseVoiceAfterBackendSpeechFallbackFailure("backend_fallback_error")
            }

            LiveSpeechTranscriptionSocketClient.Event.Closed -> {
                callbacks.markAsrClosed("backend_fallback_closed")
                if (internalUiState.value.listening && !internalUiState.value.processingTurn) {
                    callbacks.pauseVoiceAfterBackendSpeechFallbackFailure("backend_fallback_closed")
                }
            }
        }
    } }

    fun handleSpeechEvent(event: SpeechRecognitionEvent) { with(viewModel) {
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("platform_speech_${event.javaClass.simpleName}")
            return
        }
        when (event) {
            SpeechRecognitionEvent.Ready,
            SpeechRecognitionEvent.Listening -> {
                platformSpeechFallbackStarted = true
                callbacks.markAsrReady("platform_speech")
                internalUiState.update {
                    it.copy(
                        listening = true,
                        processingTurn = false,
                        status = localizedListeningStatus()
                    )
                }
            }

            SpeechRecognitionEvent.Processing -> {
                internalUiState.update {
                    it.copy(
                        listening = false,
                        processingTurn = true,
                        status = localizedConfirmingDetailsStatus()
                    )
                }
            }

            is SpeechRecognitionEvent.PartialResult -> {
                val displayText = mergeManualAsrTranscript(
                    prefix = pendingManualAsrFinalTranscript?.takeIf {
                        manualAsrButtonPressed || internalUiState.value.manualAsrFinalizing
                    },
                    next = event.text
                )
                callbacks.markAsrPartial(displayText, "platform_speech")
                internalUiState.update {
                    it.copy(
                        stage = maxStage(it.stage, AssistantStage.Clarifying),
                        status = displayText,
                        liveUserTranscript = displayText
                    )
                }
            }

            is SpeechRecognitionEvent.FinalResult -> {
                if (!platformSpeechFallbackStarted &&
                    !manualAsrButtonPressed &&
                    !internalUiState.value.manualAsrFinalizing
                ) return@with
                if (consumeManualAsrFinal(event.text, "platform_speech")) return@with
                platformSpeechFallbackStarted = false
                speechRecognizer.stop()
                callbacks.markAsrFinal("platform_speech")
                callbacks.recordAgentSubmitting(event.text, "platform_speech_final")
                callbacks.enqueueRecognizedTurn(event.text)
            }

            is SpeechRecognitionEvent.Error -> {
                val releaseFinalizing = internalUiState.value.manualAsrFinalizing
                platformSpeechFallbackStarted = false
                callbacks.markAsrError("platform_speech")
                if (releaseFinalizing) {
                    speechRecognizer.stop()
                    internalLog(
                        "VOICE_ASR platform fallback auto-resume suppressed reason=manual_release_finalizing"
                    )
                    return@with
                }
                internalUiState.update {
                    it.copy(
                        listening = false,
                        processingTurn = false,
                        error = null,
                        liveUserTranscript = null,
                        status = if (it.stage == AssistantStage.Idle) {
                            DefaultIdleStatus
                        } else {
                            localizedVoiceRecoveryResumeStatus(currentVoiceLanguage())
                        }
                    )
                }
                scheduleAutoResumeListening(AutoResumeListeningDelayMillis)
            }
        }
    } }

    private fun consumeManualAsrFinal(text: String, source: String): Boolean = with(viewModel) {
        val finalizing = internalUiState.value.manualAsrFinalizing
        if (!manualAsrButtonPressed && !finalizing) return@with false
        val normalized = text.trim()
        if (normalized.isBlank() || looksLikeAsrMetadata(normalized)) return@with true
        val merged = mergeManualAsrTranscript(
            prefix = pendingManualAsrFinalTranscript,
            next = normalized
        )
        if (manualAsrButtonPressed) {
            pendingManualAsrFinalTranscript = merged
            voiceRuntimeHandler.recordAsrFinalBuffered(merged, source)
            internalUiState.update {
                it.copy(
                    apiAsrPartialText = merged,
                    liveUserTranscript = merged
                )
            }
            return@with true
        }
        manualAsrReleaseFallbackJob?.cancel()
        manualAsrReleaseFallbackJob = null
        pendingManualAsrFinalTranscript = null
        when (source) {
            "backend_fallback" -> {
                backendSpeechFallbackActive = false
                liveSpeechClient.stop()
            }

            "platform_speech" -> {
                platformSpeechFallbackStarted = false
                speechRecognizer.stop()
            }
        }
        callbacks.markAsrFinal(source)
        internalUiState.update {
            it.copy(
                listening = false,
                voiceConnecting = false,
                apiAsrListening = false,
                manualAsrFinalizing = false,
                apiAsrPartialText = null,
                liveUserTranscript = null
            )
        }
        callbacks.recordAgentSubmitting(merged, "${source}_final")
        callbacks.enqueueRecognizedTurn(merged)
        true
    }
}
