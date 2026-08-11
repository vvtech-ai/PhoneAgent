package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceDuplexCoordinator
import com.vvtech.aiassistant.features.assistant.VoiceDuplexSpeechSource
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class LocalPromptDeps(
    val uiState: MutableStateFlow<Index9AssistantUiState>,
    val voiceDuplexCoordinator: VoiceDuplexCoordinator
)

internal class LocalPromptCallbacks(
    val isOutboundCallAudioSuppressed: () -> Boolean,
    val languageCode: () -> String,
    val setLocalTtsPlaying: (Boolean) -> Unit,
    val commitAssistantTranscript: (String) -> Unit,
    val getLastCommittedAssistantTranscript: () -> String?,
    val resumeListeningAfterTts: () -> Unit,
    val localizedListeningStatus: () -> String,
    val localizedReconnectingVoiceStatus: () -> String,
    val getPendingAutoListenAfterSelectionPrompt: () -> Boolean,
    val setPendingAutoListenAfterSelectionPrompt: (Boolean) -> Unit,
    val getActiveInteractionChannel: () -> InteractionChannel,
    val startVoiceInteraction: () -> Unit,
    val setPendingDialogTargetScene: (String?) -> Unit,
    val getActiveDialogRunId: () -> Int,
    val startApiListening: () -> Unit,
    val log: (String) -> Unit
)

internal class LocalPromptActionHandler(
    private val deps: LocalPromptDeps,
    private val callbacks: LocalPromptCallbacks
) {

    fun speakVoicePrompt(text: String) {
        val normalized = text.trim()
        if (normalized.isBlank()) return
        if (callbacks.isOutboundCallAudioSuppressed()) {
            deps.voiceDuplexCoordinator.suspendDialogAudioForCall("voice_prompt_call_active")
            return
        }
        callbacks.commitAssistantTranscript(normalized)
        callbacks.setLocalTtsPlaying(true)
        // Expose TTS text so the big button can show it during playback.
        deps.uiState.update {
            it.copy(
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                listening = false,
                processingTurn = false,
                localTtsSpeaking = true,
                liveAssistantTranscript = normalized,
                status = callbacks.localizedListeningStatus()
            )
        }
        deps.voiceDuplexCoordinator.speakLocal(
            normalized,
            source = VoiceDuplexSpeechSource.VoicePrompt,
            languageCode = callbacks.languageCode(),
            onDone = callbacks.resumeListeningAfterTts,
            onError = callbacks.resumeListeningAfterTts
        )
    }

    fun playBackendAssistantPromptFully(prompt: String?) {
        val normalized = prompt?.trim().orEmpty()
        if (normalized.isBlank()) return
        if (callbacks.isOutboundCallAudioSuppressed()) {
            deps.voiceDuplexCoordinator.suspendDialogAudioForCall("backend_prompt_call_active")
            return
        }
        callbacks.log(
            "playBackendAssistantPromptFully text=${previewText(normalized)}"
        )
        deps.uiState.update {
            it.copy(
                listening = false,
                processingTurn = false,
                localTtsSpeaking = true,
                liveAssistantTranscript = normalized,
                status = callbacks.localizedListeningStatus()
            )
        }
        callbacks.setLocalTtsPlaying(true)
        deps.voiceDuplexCoordinator.speakLocal(
            normalized,
            source = VoiceDuplexSpeechSource.BackendPrompt,
            languageCode = callbacks.languageCode(),
            onDone = {
                callbacks.setLocalTtsPlaying(false)
                deps.uiState.update {
                    AssistantUiStateReducer.clearLocalAssistantSpeaking(it)
                }
                resumeVoiceSelectionListeningAfterPrompt()
            },
            onError = {
                callbacks.setLocalTtsPlaying(false)
                deps.uiState.update {
                    AssistantUiStateReducer.clearLocalAssistantSpeaking(it)
                }
                resumeVoiceSelectionListeningAfterPrompt()
            }
        )
    }

    fun presentSyntheticAssistantQuestion(
        text: String,
        restartRealtimeAfterPlayback: Boolean = false
    ) {
        val normalized = text.trim()
        if (normalized.isBlank()) {
            return
        }
        if (callbacks.isOutboundCallAudioSuppressed()) {
            deps.voiceDuplexCoordinator.suspendDialogAudioForCall("synthetic_prompt_call_active")
            return
        }
        var transcriptCommitted = normalized == callbacks.getLastCommittedAssistantTranscript()
        deps.uiState.update {
            it.copy(
                voiceConnecting = false,
                voiceActive = false,
                listening = false,
                processingTurn = false,
                localTtsSpeaking = true,
                liveAssistantTranscript = normalized,
                error = null,
                status = callbacks.localizedListeningStatus()
            )
        }
        callbacks.setLocalTtsPlaying(true)
        deps.voiceDuplexCoordinator.speakLocal(
            normalized,
            source = VoiceDuplexSpeechSource.SyntheticPrompt,
            languageCode = callbacks.languageCode(),
            onStart = {
                if (!transcriptCommitted) {
                    callbacks.commitAssistantTranscript(normalized)
                    transcriptCommitted = true
                }
            },
            onDone = {
                callbacks.setLocalTtsPlaying(false)
                deps.uiState.update {
                    AssistantUiStateReducer.clearLocalAssistantSpeaking(it)
                }
                if (!transcriptCommitted) {
                    callbacks.commitAssistantTranscript(normalized)
                    transcriptCommitted = true
                }
                if (restartRealtimeAfterPlayback) {
                    resumeRealtimeAfterSyntheticPromptPlayback()
                }
            },
            onError = {
                callbacks.setLocalTtsPlaying(false)
                deps.uiState.update {
                    AssistantUiStateReducer.clearLocalAssistantSpeaking(it)
                }
                if (!transcriptCommitted) {
                    callbacks.commitAssistantTranscript(normalized)
                    transcriptCommitted = true
                }
                if (restartRealtimeAfterPlayback) {
                    resumeRealtimeAfterSyntheticPromptPlayback()
                }
            }
        )
    }

    internal fun resumeVoiceSelectionListeningAfterPrompt() {
        if (!callbacks.getPendingAutoListenAfterSelectionPrompt()) return
        callbacks.setPendingAutoListenAfterSelectionPrompt(false)
        val state = deps.uiState.value
        if (
            callbacks.getActiveInteractionChannel() != InteractionChannel.VOICE ||
            callbacks.isOutboundCallAudioSuppressed() ||
            state.selectionSheet == null ||
            state.voiceConnecting ||
            state.voiceActive ||
            state.listening ||
            state.processingTurn
        ) {
            callbacks.log(
                "resumeVoiceSelectionListeningAfterPrompt skipped selection=${state.selectionSheet != null} " +
                    "voiceActive=${state.voiceActive} listening=${state.listening} processing=${state.processingTurn}"
            )
            return
        }
        callbacks.log("resumeVoiceSelectionListeningAfterPrompt start selection voice capture")
        callbacks.startVoiceInteraction()
    }

    private fun resumeRealtimeAfterSyntheticPromptPlayback() {
        val state = deps.uiState.value
        if (
            callbacks.getActiveInteractionChannel() != InteractionChannel.VOICE ||
            callbacks.isOutboundCallAudioSuppressed() ||
            state.selectionSheet != null ||
            state.summary != null
        ) {
            callbacks.setPendingDialogTargetScene(null)
            deps.uiState.update {
                it.copy(
                    voiceConnecting = false,
                    voiceActive = false,
                    listening = false,
                    processingTurn = false
                )
            }
            return
        }
        callbacks.log(
            "resumeRealtimeAfterSyntheticPromptPlayback -> dialog ASR runId=${callbacks.getActiveDialogRunId()} " +
                "scene=${deps.uiState.value.sceneType}"
        )
        deps.uiState.update {
            it.copy(
                voiceConnecting = true,
                voiceActive = false,
                listening = false,
                processingTurn = false,
                error = null,
                status = callbacks.localizedReconnectingVoiceStatus()
            )
        }
        callbacks.startApiListening()
    }
}
