package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.TaskVoiceCloseReason
import com.vvtech.aiassistant.features.assistant.VoicePauseSource
import com.vvtech.aiassistant.features.assistant_voice.VoiceManualControlHandler
import com.vvtech.aiassistant.features.assistant.isNetworkTaskStatus
import com.vvtech.aiassistant.features.assistant.shouldSyncConversationBeforeVoiceResume
import com.vvtech.aiassistant.features.assistant.voicePauseFlagsFor
import com.vvtech.aiassistant.features.assistant_tasks.shouldClearCallResultForContinuation
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class VoiceEntryActionHandler(
    private val viewModel: AssistantViewModel
) {
    private val manualControlHandler = VoiceManualControlHandler(viewModel)

    fun pauseVoiceInputFromUser() {
        with(viewModel) {
        autoResumeListeningJob?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        val ttsPlaying =
            localTtsPlaying || internalUiState.value.localTtsSpeaking || internalUiState.value.apiTtsPlaying
        if (ttsPlaying) {
            internalLog(
                "VOICE_INPUT interrupt_tts reason=${TaskVoiceCloseReason.ManualTtsInterrupt.logKey} source=pause_voice_input " +
                    "apiTtsPlaying=${internalUiState.value.apiTtsPlaying} localTtsSpeaking=${internalUiState.value.localTtsSpeaking}"
            )
            ttsBridge.interrupt()
            agentStreamHandler.interruptCurrentStream()
            assistantSpeechPlayer.stop()
            localTtsPlaying = false
        }
        closeTaskVoiceRealtime("pause_voice_input")
        if (internalUiState.value.apiAsrListening || voiceDuplexCoordinator.dialogAsrActive) {
            stopApiListening()
        } else if (internalUiState.value.voiceConnecting || internalUiState.value.voiceActive || internalUiState.value.listening) {
            stopLiveTranscription(suppressRestart = true)
        }
        val pauseFlags = voicePauseFlagsFor(VoicePauseSource.User)
        internalUiState.update {
            val keepNetworkError = isNetworkTaskStatus(it.taskStatus)
            it.copy(
                voiceManuallyPaused = pauseFlags.manuallyPaused,
                voiceBackgroundPaused = pauseFlags.backgroundPaused,
                listening = false,
                voiceConnecting = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = if (ttsPlaying) false else it.apiTtsPlaying,
                localTtsSpeaking = if (ttsPlaying) false else it.localTtsSpeaking,
                liveAssistantTranscript = if (ttsPlaying) null else it.liveAssistantTranscript,
                error = if (keepNetworkError) it.error else null,
                status = if (keepNetworkError) it.status else localizedPausedTapToContinueStatus()
            )
        }
        }
    }

    fun resumeVoiceInputFromUser() {
        with(viewModel) {
        autoResumeListeningJob?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("resume_voice_input_call_active")
            return
        }
        val sessionId = agentSessionId?.trim()?.takeIf { it.isNotBlank() }
        val shouldSyncBeforeResume = shouldSyncConversationBeforeVoiceResume(
            sessionId = sessionId,
            taskStatus = internalUiState.value.taskStatus,
            status = internalUiState.value.status,
            processingTurn = internalUiState.value.processingTurn
        )
        val resumingFromNetworkError = isNetworkTaskStatus(internalUiState.value.taskStatus)
        val recoverableBaseText = voiceRecoverableTurnCoordinator.recoverableBaseText()
        if (resumingFromNetworkError) {
            closeTaskVoiceRealtime("resume_from_network_error")
        }
        internalUiState.update {
            it.copy(
                stage = if (it.stage == AssistantStage.Recognized) {
                    AssistantStage.Clarifying
                } else {
                    maxStage(it.stage, AssistantStage.Clarifying)
                },
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceConnecting = true,
                voiceActive = false,
                listening = false,
                processingTurn = false,
                taskStatus = if (isNetworkTaskStatus(it.taskStatus)) "ACTIVE" else it.taskStatus,
                taskErrorRecoveryInProgress = if (resumingFromNetworkError) true else it.taskErrorRecoveryInProgress,
                error = null,
                liveUserTranscript = recoverableBaseText,
                status = if (shouldSyncBeforeResume) {
                    localizedReconnectingVoiceStatus()
                } else {
                    localizedListeningStatus()
                }
            )
        }
        viewModelScope.launch {
            val canContinue = if (shouldSyncBeforeResume) {
                syncConversationSnapshotForVoiceRecovery(sessionId.orEmpty(), "voice_resume")
            } else {
                true
            }
            if (!canContinue || activeInteractionChannel != InteractionChannel.VOICE) {
                return@launch
            }
            internalUiState.update {
                it.copy(
                    voiceManuallyPaused = false,
                    voiceBackgroundPaused = false,
                    voiceConnecting = true,
                    voiceActive = false,
                    listening = false,
                    processingTurn = false,
                    taskStatus = if (isNetworkTaskStatus(it.taskStatus)) "ACTIVE" else it.taskStatus,
                    taskErrorRecoveryInProgress = if (resumingFromNetworkError) true else it.taskErrorRecoveryInProgress,
                    error = null,
                    liveUserTranscript = recoverableBaseText,
                    liveAssistantTranscript = null,
                    status = localizedReconnectingVoiceStatus()
                )
            }
            startApiListening()
        }
        }
    }

    fun onMicClick() {
        with(viewModel) {
        autoResumeListeningJob?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("mic_click_call_active")
            return
        }
        val currentState = internalUiState.value
        val clearCallResult = shouldClearCallResultForContinuation(
            currentState.taskStatus,
            currentState.agentCallResult
        )
        if (!clearCallResult && currentState.voiceManuallyPaused) {
            this@VoiceEntryActionHandler.resumeVoiceInputFromUser()
            return
        }
        if (!clearCallResult && currentState.voiceConnecting) {
            internalLog("onMicClick -> pause while voice connection is pending")
            this@VoiceEntryActionHandler.pauseVoiceInputFromUser()
            return
        }
        if (!clearCallResult && currentState.voiceActive && !currentState.listening && !currentState.processingTurn) {
            this@VoiceEntryActionHandler.pauseVoiceInputFromUser()
            return
        }
        if (!clearCallResult && internalUiState.value.listening) {
            val fallbackTranscript = internalUiState.value.liveUserTranscript?.trim().orEmpty()
            stopApiListening()
            if (fallbackTranscript.isNotBlank()) {
                viewModelScope.launch {
                    delay(ManualFinishFallbackDelayMillis)
                    val state = internalUiState.value
                    if (!state.processingTurn && state.liveUserTranscript?.trim() == fallbackTranscript) {
                        enqueueRecognizedTurn(fallbackTranscript)
                    }
                }
            }
            return
        }
        if (clearCallResult) {
            ttsBridge.interrupt()
            assistantSpeechPlayer.stop()
            localTtsPlaying = false
            internalLog("onMicClick clearing terminal call result UI before continuation")
        }

        pendingFreshTask = activeVoiceTaskId().isNullOrBlank()
        if (pendingFreshTask) {
            viewModelScope.launch {
                refreshLocationIfPermitted(force = true, reason = "voice_session_start")
            }
        }
        internalUiState.update {
            val baseState = if (clearCallResult) {
                AssistantUiStateReducer.clearCallResultUiForContinuation(it)
            } else {
                it
            }
            baseState.copy(
                stage = if (it.stage == AssistantStage.Recognized) {
                    AssistantStage.Clarifying
                } else {
                    maxStage(it.stage, AssistantStage.Clarifying)
                },
                // Do NOT set listening=true while local TTS is still playing 鈥?
                // resumeListeningAfterTts() will flip it once the speech finishes.
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceConnecting = false,
                voiceActive = false,
                listening = !localTtsPlaying,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = if (clearCallResult) false else it.apiTtsPlaying,
                localTtsSpeaking = if (clearCallResult) false else it.localTtsSpeaking,
                error = null,
                liveUserTranscript = null,
                // Preserve the TTS text while local speech is playing so the big button shows it.
                liveAssistantTranscript = if (!clearCallResult && localTtsPlaying) it.liveAssistantTranscript else null,
                status = if (localTtsPlaying) localizedListeningStatus() else localizedStartingVoiceStatus()
            )
        }
        internalLog(
            "onMicClick -> startApiListening reason=user_tap_mic stage=${internalUiState.value.stage} " +
                    "scene=${internalUiState.value.sceneType} activeTaskId=${activeVoiceTaskId()}"
        )
        startApiListening()
        }
    }

    fun onApiMicClick() {
        with(viewModel) {
        autoResumeListeningJob?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("api_mic_click_call_active")
            return
        }

        val clearCallResult = shouldClearCallResultForContinuation(
            internalUiState.value.taskStatus,
            internalUiState.value.agentCallResult
        )

        if (!clearCallResult && internalUiState.value.voiceManuallyPaused) {
            this@VoiceEntryActionHandler.resumeVoiceInputFromUser()
            return
        }

        if (!clearCallResult && internalUiState.value.voiceConnecting) {
            internalLog(
                "onApiMicClick ignored while voiceConnecting " +
                        "dialogAsrActive=${voiceDuplexCoordinator.dialogAsrActive} " +
                        "apiTtsPlaying=${internalUiState.value.apiTtsPlaying}"
            )
            return
        }

        if (!clearCallResult &&
            (internalUiState.value.apiAsrListening ||
                    (voiceDuplexCoordinator.dialogAsrActive && !internalUiState.value.apiTtsPlaying))
        ) {
            stopApiListening()
            return
        }

        if (!clearCallResult && internalUiState.value.apiTtsPlaying) {
            this@VoiceEntryActionHandler.onTtsInterrupted()
            return
        }

        if (clearCallResult) {
            ttsBridge.interrupt()
            assistantSpeechPlayer.stop()
            localTtsPlaying = false
            internalLog("onApiMicClick clearing terminal call result UI before continuation")
        }

        internalUiState.update {
            val baseState = if (clearCallResult) {
                AssistantUiStateReducer.clearCallResultUiForContinuation(it)
            } else {
                it
            }
            baseState.copy(
                stage = if (it.stage == AssistantStage.Recognized) {
                    AssistantStage.Clarifying
                } else {
                    maxStage(it.stage, AssistantStage.Clarifying)
                },
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceConnecting = true,
                voiceActive = false,
                listening = false,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = if (clearCallResult) false else it.apiTtsPlaying,
                localTtsSpeaking = if (clearCallResult) false else it.localTtsSpeaking,
                error = null,
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                status = localizedConnectingVoiceStatus()
            )
        }
        startApiListening()
        }
    }

    fun onManualAsrPress() {
        manualControlHandler.onManualAsrPress()
    }

    fun onManualAsrRelease() {
        manualControlHandler.onManualAsrRelease()
    }

    fun onManualAsrCancel() {
        manualControlHandler.onManualAsrCancel()
    }

    fun onManualAsrTooShort() {
        manualControlHandler.onManualAsrTooShort()
    }

    fun onTtsInterrupted() {
        manualControlHandler.onTtsInterrupted()
    }

    fun stopTtsPlaybackForOptionSelection() {
        with(viewModel) {
            internalLog("TTS_CONTROL stop_playback source=agent_option_selection")
            ttsBridge.interrupt()
            assistantSpeechPlayer.stop()
            localTtsPlaying = false
            internalUiState.update {
                it.copy(apiTtsPlaying = false, localTtsSpeaking = false)
            }
        }
    }

    fun startVoiceInteraction() {
        with(viewModel) {
        val state = internalUiState.value
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("start_voice_interaction_call_active")
            return
        }
        if (state.voiceManuallyPaused) {
            this@VoiceEntryActionHandler.resumeVoiceInputFromUser()
            return
        }
        if (state.voiceConnecting || state.listening || state.processingTurn || state.showAiCallPage) return
        if (state.voiceActive) return
        this@VoiceEntryActionHandler.onMicClick()
        }
    }

    fun startVoiceInteractionForNewTaskEntry() {
        with(viewModel) {
        autoResumeListeningJob?.cancel()
        cancelTextProcessingStatusProgress()
        activeInteractionChannel = InteractionChannel.VOICE
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("new_task_voice_entry_call_active")
            return
        }
        voiceRuntimeHandler.cancelAsrInputWatchdogs("new_task_voice_entry")
        voiceDuplexCoordinator.clearOpenListeningForNewTaskEntry("new_task_voice_entry")
        viewModelScope.launch {
            refreshLocationIfPermitted(force = true, reason = "new_task_voice_entry")
        }
        internalUiState.update {
            it.copy(
                stage = if (it.stage == AssistantStage.Recognized) {
                    AssistantStage.Clarifying
                } else {
                    maxStage(it.stage, AssistantStage.Clarifying)
                },
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                voiceConnecting = false,
                voiceActive = false,
                listening = !localTtsPlaying && !it.localTtsSpeaking && !it.apiTtsPlaying,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                error = null,
                liveUserTranscript = null,
                liveAssistantTranscript = if (localTtsPlaying || it.localTtsSpeaking || it.apiTtsPlaying) {
                    it.liveAssistantTranscript
                } else {
                    null
                },
                status = if (localTtsPlaying || it.localTtsSpeaking || it.apiTtsPlaying) {
                    currentVoiceLanguage().standbyText
                } else {
                    localizedStartingVoiceStatus()
                }
            )
        }
        internalLog(
            "startVoiceInteractionForNewTaskEntry -> startApiListening " +
                    "scene=${internalUiState.value.sceneType} activeTaskId=${activeVoiceTaskId()}"
        )
        startApiListening()
        }
    }

    fun toggleVoiceInputFromUser() {
        with(viewModel) {
        val state = internalUiState.value
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("toggle_voice_input_call_active")
            return
        }
        if (state.voiceManuallyPaused) {
            this@VoiceEntryActionHandler.resumeVoiceInputFromUser()
            return
        }
        if (
            state.voiceConnecting ||
            state.voiceActive ||
            state.listening ||
            state.processingTurn ||
            state.apiAsrListening ||
            voiceDuplexCoordinator.dialogAsrActive ||
            state.localTtsSpeaking ||
            state.apiTtsPlaying
        ) {
            this@VoiceEntryActionHandler.pauseVoiceInputFromUser()
            return
        }
        this@VoiceEntryActionHandler.onMicClick()
        }
    }
}
