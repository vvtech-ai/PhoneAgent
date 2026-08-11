package com.vvtech.aiassistant.features.assistant

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.features.assistant.viewmodel.AutoResumeListeningDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.detectLocalSceneHint
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.textProcessingStatusLabel
import com.vvtech.aiassistant.features.assistant_voice.TaskVoiceTurnStateMachine
import com.vvtech.aiassistant.features.assistant_voice.VoiceRuntimeEventRecorder
import com.vvtech.aiassistant.features.assistant_voice.VoiceFallbackSpeechEventCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceFallbackSpeechEventHandler
import com.vvtech.aiassistant.features.assistant_voice.VoiceAsrWatchdogCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceAsrWatchdogController
import com.vvtech.aiassistant.features.assistant_voice.VoiceRecognizedTurnQueueController
import com.vvtech.aiassistant.features.assistant_voice.VoiceRealtimeLocalTranscriptCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceRealtimeLocalTranscriptHandler
import com.vvtech.aiassistant.features.assistant_voice.VoiceRealtimeAssistantSpeechCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceRealtimeAssistantSpeechHandler
import com.vvtech.aiassistant.features.assistant_voice.VoiceRuntimeLifecycleCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceRuntimeLifecycleController
import com.vvtech.aiassistant.features.assistant_voice.VoiceRuntimeSessionCallbacks
import com.vvtech.aiassistant.features.assistant_voice.VoiceRuntimeSessionController
import com.vvtech.aiassistant.features.assistant_voice.VoiceListenTriggers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

internal class VoiceRuntimeHandler(private val viewModel: AssistantViewModel) {

    private val voiceRuntimeEventRecorder = VoiceRuntimeEventRecorder()
    private val taskVoiceTurnStateMachine = TaskVoiceTurnStateMachine(
        logger = { message -> viewModel.internalLog(message) },
        transitionListener = { transition ->
            voiceRuntimeEventRecorder.record(transition, activeVoiceTaskId())
        }
    )
    private val recognizedTurnQueueController = VoiceRecognizedTurnQueueController(viewModel)
    private val realtimeLocalTranscriptHandler = VoiceRealtimeLocalTranscriptHandler(
        viewModel = viewModel,
        callbacks = object : VoiceRealtimeLocalTranscriptCallbacks {
            override fun markAsrFinal(source: String) {
                this@VoiceRuntimeHandler.markAsrFinal(source)
            }

            override fun markAsrPartial(text: String, source: String) {
                this@VoiceRuntimeHandler.markAsrPartial(text, source)
            }

            override fun recordAgentSubmitting(text: String, source: String) {
                this@VoiceRuntimeHandler.recordAgentSubmitting(text, source)
            }

            override fun stopLiveTranscription() {
                this@VoiceRuntimeHandler.stopLiveTranscription()
            }

            override fun enqueueRecognizedTurn(text: String) {
                this@VoiceRuntimeHandler.enqueueRecognizedTurn(text)
            }
        }
    )
    private val fallbackSpeechEventHandler = VoiceFallbackSpeechEventHandler(
        viewModel = viewModel,
        callbacks = object : VoiceFallbackSpeechEventCallbacks {
            override fun markAsrReady(source: String) {
                this@VoiceRuntimeHandler.markAsrReady(source)
            }

            override fun markAsrPartial(text: String, source: String) {
                this@VoiceRuntimeHandler.markAsrPartial(text, source)
            }

            override fun markAsrFinal(source: String) {
                this@VoiceRuntimeHandler.markAsrFinal(source)
            }

            override fun markAsrError(source: String) {
                this@VoiceRuntimeHandler.markAsrError(source)
            }

            override fun markAsrClosed(source: String) {
                this@VoiceRuntimeHandler.markAsrClosed(source)
            }

            override fun recordAgentSubmitting(text: String, source: String) {
                this@VoiceRuntimeHandler.recordAgentSubmitting(text, source)
            }

            override fun enqueueRecognizedTurn(text: String) {
                this@VoiceRuntimeHandler.enqueueRecognizedTurn(text)
            }

            override fun pauseVoiceAfterBackendSpeechFallbackFailure(reason: String) {
                this@VoiceRuntimeHandler.pauseVoiceAfterBackendSpeechFallbackFailure(reason)
            }
        }
    )
    private val asrWatchdogController: VoiceAsrWatchdogController = VoiceAsrWatchdogController(
        viewModel = viewModel,
        callbacks = object : VoiceAsrWatchdogCallbacks {
            override fun onAsrReady(source: String) {
                taskVoiceTurnStateMachine.onAsrReady(source = source)
            }

            override fun onAsrPartial(text: String, source: String) {
                taskVoiceTurnStateMachine.onAsrPartial(text = text, source = source)
            }

            override fun onProviderError(source: String) {
                taskVoiceTurnStateMachine.onProviderError(source = source)
            }

            override fun onProviderClosed(source: String) {
                taskVoiceTurnStateMachine.onProviderClosed(source = source)
            }

            override fun onManualAsrTimeout(source: String) {
                taskVoiceTurnStateMachine.onManualAsrTimeout(source = source)
            }

            override fun startBackendSpeechFallback() {
                this@VoiceRuntimeHandler.startBackendSpeechFallback()
            }
        }
    )
    private val realtimeAssistantSpeechHandler: VoiceRealtimeAssistantSpeechHandler = VoiceRealtimeAssistantSpeechHandler(
        viewModel = viewModel,
        callbacks = object : VoiceRealtimeAssistantSpeechCallbacks {
            override fun stopLiveTranscription(suppressRestart: Boolean) {
                this@VoiceRuntimeHandler.stopLiveTranscription(suppressRestart)
            }

            override fun submitPendingStructuredTurn(
                understanding: StructuredAssistantUnderstanding?,
                reason: String
            ): Boolean =
                this@VoiceRuntimeHandler.submitPendingStructuredTurn(understanding, reason)

            override fun appendClarificationStep(role: VoiceRole, text: String) {
                viewModel.appendClarificationStep(role, text)
            }

            override fun resumeListeningAfterTts() {
                this@VoiceRuntimeHandler.resumeListeningAfterTts()
            }
        }
    )
    private val lifecycleController: VoiceRuntimeLifecycleController = VoiceRuntimeLifecycleController(
        viewModel = viewModel,
        callbacks = object : VoiceRuntimeLifecycleCallbacks {
            override fun recordVoiceTurnClosed(reason: TaskVoiceCloseReason, source: String) {
                this@VoiceRuntimeHandler.recordVoiceTurnClosed(reason, source)
            }

            override fun cancelAsrInputWatchdogs(reason: String) {
                this@VoiceRuntimeHandler.cancelAsrInputWatchdogs(reason)
            }

            override fun cancelManualAsrSessionTimeout(reason: String) {
                this@VoiceRuntimeHandler.cancelManualAsrSessionTimeout(reason)
            }

            override fun startAsrInputWatchdog(source: String) {
                this@VoiceRuntimeHandler.startAsrInputWatchdog(source)
            }

            override fun resetRecognizedTurnDedup() {
                recognizedTurnQueueController.resetDedup()
                viewModel.voiceRecognizedInputDedupTracker.reset()
            }

            override fun activeVoiceTaskId(): String? =
                this@VoiceRuntimeHandler.activeVoiceTaskId()

            override fun handleLiveTranscriptionEvent(
                captureGeneration: Long,
                event: LiveSpeechTranscriptionSocketClient.Event
            ) {
                this@VoiceRuntimeHandler.handleLiveTranscriptionEvent(captureGeneration, event)
            }
        }
    )
    private val sessionController: VoiceRuntimeSessionController = VoiceRuntimeSessionController(
        viewModel = viewModel,
        callbacks = object : VoiceRuntimeSessionCallbacks {
            override fun cancelAsrInputWatchdogs(reason: String) {
                this@VoiceRuntimeHandler.cancelAsrInputWatchdogs(reason)
            }

            override fun startBackendSpeechFallback() {
                this@VoiceRuntimeHandler.startBackendSpeechFallback()
            }

            override fun startApiListening(trigger: String) {
                this@VoiceRuntimeHandler.startApiListening(trigger)
            }
        }
    )

    internal fun recordManualAsrPress(ttsPlaying: Boolean, source: String) {
        taskVoiceTurnStateMachine.onManualAsrPress(ttsPlaying = ttsPlaying, source = source)
    }

    internal fun recordManualReleaseSubmit(text: String, source: String) {
        taskVoiceTurnStateMachine.onManualReleaseSubmit(text = text, source = source)
    }

    internal fun recordManualReleaseNoTranscript(source: String) {
        taskVoiceTurnStateMachine.onManualReleaseNoTranscript(source = source)
    }

    internal fun recordAgentSubmitting(text: String, source: String) {
        taskVoiceTurnStateMachine.onAgentSubmitting(text = text, source = source)
    }

    internal fun recordAsrFinalBuffered(text: String, source: String) {
        taskVoiceTurnStateMachine.onAsrFinalBuffered(text = text, source = source)
    }

    internal fun recordTtsPlaybackStarted(source: String) {
        taskVoiceTurnStateMachine.onTtsPlaybackStarted(source = source)
    }

    internal fun recordTtsPlaybackCompleted(source: String) {
        taskVoiceTurnStateMachine.onTtsPlaybackCompleted(source = source)
    }

    internal fun recordTtsPlaybackFailed(source: String) {
        taskVoiceTurnStateMachine.onTtsPlaybackFailed(source = source)
    }

    internal fun recordManualTtsInterrupt(source: String, startAsrAfter: Boolean) {
        taskVoiceTurnStateMachine.onManualTtsInterrupt(source = source, startAsrAfter = startAsrAfter)
    }

    internal fun recordVoiceTurnClosed(reason: TaskVoiceCloseReason, source: String) {
        taskVoiceTurnStateMachine.close(reason = reason, source = source)
    }

    internal fun stopVoiceInteraction(reason: String = "stop_voice_interaction") =
        lifecycleController.stopVoiceInteraction(reason)

    internal fun closeTaskVoiceRealtime(reason: String) =
        lifecycleController.closeTaskVoiceRealtime(reason)

    internal var dialogAsrActive: Boolean
        get() = viewModel.voiceDuplexCoordinator.dialogAsrActive
        set(value) {
            viewModel.voiceDuplexCoordinator.dialogAsrActive = value
        }

    internal fun startApiListening(trigger: String = VoiceListenTriggers.Unspecified) =
        sessionController.startApiListening(trigger)

    internal fun stopApiListening(preserveLateFinalGrace: Boolean = false) {
        sessionController.stopApiListening(preserveLateFinalGrace)
    }

    internal fun startAsrInputWatchdog(source: String) =
        asrWatchdogController.startAsrInputWatchdog(source)

    internal fun markAsrReady(source: String) =
        asrWatchdogController.markAsrReady(source)

    internal fun markAsrPartial(text: String, source: String) =
        asrWatchdogController.markAsrPartial(text, source)

    internal fun markAsrFinal(source: String) =
        asrWatchdogController.markAsrFinal(source)

    internal fun markAsrError(source: String) =
        asrWatchdogController.markAsrError(source)

    internal fun markAsrClosed(source: String) =
        asrWatchdogController.markAsrClosed(source)

    internal fun cancelAsrInputWatchdogs(reason: String) =
        asrWatchdogController.cancelAsrInputWatchdogs(reason)

    internal fun startManualAsrSessionTimeout(source: String) =
        asrWatchdogController.startManualAsrSessionTimeout(source)

    internal fun cancelManualAsrSessionTimeout(reason: String) =
        asrWatchdogController.cancelManualAsrSessionTimeout(reason)

    internal fun shouldDropDuplicateRecognizedText(text: String, source: String): Boolean =
        asrWatchdogController.shouldDropDuplicateRecognizedText(text, source)

    internal fun startTaskVoiceAsrSession(
        startReason: String,
        onEvent: (TaskVoiceAsrEvent) -> Unit,
        beforeStart: (() -> Unit)? = null
    ): Boolean =
        sessionController.startTaskVoiceAsrSession(startReason, onEvent, beforeStart)

    internal fun startLiveTranscription() =
        sessionController.startLiveTranscription()

    internal fun stopLiveTranscription(suppressRestart: Boolean = true) =
        sessionController.stopLiveTranscription(suppressRestart)

    internal fun ensureRealtimeSession(silentResume: Boolean = false) =
        sessionController.ensureRealtimeSession(silentResume)

    internal fun stopRealtimeSession() =
        lifecycleController.stopRealtimeSession()

    internal fun resumeListeningAfterTts() =
        lifecycleController.resumeListeningAfterTts()

    internal fun startBackendSpeechFallback() =
        lifecycleController.startBackendSpeechFallback()

    internal fun activeVoiceTaskId(): String? { with(viewModel) {
        return voiceTaskId
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?: internalUiState.value.taskId
                ?.trim()
                ?.takeIf { it.isNotBlank() }
    }
    }

    private fun handleRealtimeStructuredAssistantResponse(understanding: StructuredAssistantUnderstanding) =
        realtimeAssistantSpeechHandler.handleRealtimeStructuredAssistantResponse(understanding)

    private fun submitPendingStructuredTurn(
        understanding: StructuredAssistantUnderstanding?,
        reason: String
    ): Boolean =
        realtimeLocalTranscriptHandler.submitPendingStructuredTurn(understanding, reason)

    private fun submitPendingStructuredFallbackIfNeeded(): Boolean =
        realtimeLocalTranscriptHandler.submitPendingStructuredFallbackIfNeeded()

    internal fun ensureSceneDialogContext(
        session: AssistantSessionResponse,
        carryoverUtterance: String?,
        syntheticAssistantPrompt: String?,
        forceRestart: Boolean
    ) { with(viewModel) {
        val taskId = session.session.taskId
        val sceneType = session.session.sceneType
        if (taskId.isBlank() || sceneType.isBlank() || sceneType == "GENERAL") {
            return
        }
        internalLog(
            "ensureSceneDialogContext runId=$activeDialogRunId taskId=$taskId scene=$sceneType " +
                "previousDialogScene=${activeDialogContext?.sceneType} previousBot=${activeDialogContext?.botName} " +
                "carryover=${previewText(carryoverUtterance)} synthetic=${previewText(syntheticAssistantPrompt)} " +
                "forceRestart=$forceRestart"
        )
        internalLog("ensureSceneDialogContext realtime disabled; using backend prompt plus dialog ASR")
        activeDialogContext = null
        pendingDialogTargetScene = null
        pendingCarryoverScene = null
        pendingCarryoverUtterance = null
        pendingSyntheticAssistantPrompt = null
        internalUiState.update {
            it.copy(
                sceneType = sceneType,
                voiceConnecting = false,
                voiceActive = false,
                listening = false,
                processingTurn = false,
                error = null,
                status = localizedListeningStatus()
            )
        }
        val promptToSpeak = syntheticAssistantPrompt
            ?.trim()
            ?.takeIf { it.isNotBlank() }
        if (promptToSpeak != null) {
            presentSyntheticAssistantQuestion(
                text = promptToSpeak,
                restartRealtimeAfterPlayback = true
            )
        } else {
            scheduleAutoResumeListening(AutoResumeListeningDelayMillis)
        }
    }
    }

    internal fun scheduleTextProcessingStatusProgress(text: String) { with(viewModel) {
        val predictedScene = predictTextProcessingScene(text)
        textProcessingStatusJob?.cancel()
        textProcessingStatusJob = viewModelScope.launch {
            delay(1200L)
            if (!isActive) return@launch
            internalUiState.update { current ->
                if (activeInteractionChannel != InteractionChannel.TEXT || !current.processingTurn) {
                    current
                } else {
                    current.copy(status = textProcessingStatusLabel(predictedScene))
                }
            }
        }
    }
    }

    internal fun cancelTextProcessingStatusProgress() { with(viewModel) {
        textProcessingStatusJob?.cancel()
        textProcessingStatusJob = null
    }
    }

    private fun predictTextProcessingScene(text: String): String { with(viewModel) {
        val currentScene = internalUiState.value.sceneType
        return when {
            currentScene == "FOOD_ORDERING" || currentScene == "HOTEL_BOOKING" -> currentScene
            else -> detectLocalSceneHint(text)
        }
    }
    }

    internal fun handleTakeoverAudioEvent(event: TakeoverAudioSocketClient.Event) =
        viewModel.callActionHandler.handleTakeoverAudioEvent(event)

    internal fun scheduleTakeoverReconnect(delayMillis: Long = 450L) =
        viewModel.callActionHandler.scheduleTakeoverReconnect(delayMillis)

    private fun handleLiveTranscriptionEvent(
        captureGeneration: Long,
        event: LiveSpeechTranscriptionSocketClient.Event
    ) {
        viewModel.viewModelScope.launch {
            if (captureGeneration != viewModel.backendSpeechFallbackGeneration ||
                !viewModel.backendSpeechFallbackActive
            ) {
                viewModel.internalLog(
                    "VOICE_ASR backend fallback event ignored reason=stale_capture " +
                        "event=${event.javaClass.simpleName} captureGeneration=$captureGeneration " +
                        "currentGeneration=${viewModel.backendSpeechFallbackGeneration}"
                )
                return@launch
            }
            fallbackSpeechEventHandler.handleLiveTranscriptionEvent(event)
        }
    }

    private fun pauseVoiceAfterBackendSpeechFallbackFailure(reason: String) =
        lifecycleController.pauseVoiceAfterBackendSpeechFallbackFailure(reason)

    private fun handleSpeechEvent(event: SpeechRecognitionEvent) =
        fallbackSpeechEventHandler.handleSpeechEvent(event)

    internal fun enqueueRecognizedTurn(text: String) =
        recognizedTurnQueueController.enqueueRecognizedTurn(text)
}
