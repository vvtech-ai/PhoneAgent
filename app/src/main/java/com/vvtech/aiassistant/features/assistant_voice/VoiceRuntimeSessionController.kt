package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.TaskVoiceAsrEvent
import com.vvtech.aiassistant.features.assistant.localizedVoiceUnavailableStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.flow.update

internal interface VoiceRuntimeSessionCallbacks {
    fun cancelAsrInputWatchdogs(reason: String)
    fun startBackendSpeechFallback()
    fun startApiListening(trigger: String)
}

internal class VoiceRuntimeSessionController(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceRuntimeSessionCallbacks
) {
    fun startApiListening(trigger: String = VoiceListenTriggers.Unspecified) { with(viewModel) {
        val state = internalUiState.value
        val callAudioSuppressed = isOutboundCallAudioSuppressed()
        logVoiceListen(
            eventType = "VOICE_LISTEN_REQUESTED",
            trigger = trigger,
            result = "requested",
            stateAfter = "gate_check",
            callAudioSuppressed = callAudioSuppressed
        )
        logOutboundCallAudioGate("startApiListening_entry", callAudioSuppressed)
        if (callAudioSuppressed) {
            logVoiceListen(
                eventType = "VOICE_LISTEN_BLOCKED",
                trigger = trigger,
                result = "blocked",
                reason = "call_audio_suppressed",
                callAudioSuppressed = true
            )
            voiceDuplexCoordinator.suspendDialogAudioForCall("start_api_listening_call_active")
            return
        }
        if (ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            internalLog("startApiListening skipped: RECORD_AUDIO permission not granted")
            logVoiceListen(
                eventType = "VOICE_LISTEN_BLOCKED",
                trigger = trigger,
                result = "blocked",
                reason = "missing_record_audio_permission",
                callAudioSuppressed = false
            )
            callbacks.cancelAsrInputWatchdogs("missing_record_audio_permission")
            internalUiState.update {
                it.copy(
                    voiceManuallyPaused = true,
                    voiceBackgroundPaused = false,
                    voiceConnecting = false,
                    voiceActive = true,
                    listening = false,
                    processingTurn = false,
                    apiAsrListening = false,
                    apiAsrPartialText = null,
                    liveUserTranscript = null,
                    error = null,
                    status = localizedVoiceUnavailableStatus()
                )
            }
            return
        }
        speechFallbackStarted = false
        platformSpeechFallbackStarted = false
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.ASR,
                eventType = "VOICE_LISTEN_ALLOWED",
                sessionId = agentSessionId,
                taskId = state.taskId,
                callId = state.currentCallId,
                provider = taskVoiceProvider,
                trigger = trigger,
                stateBefore = voiceListenState(state),
                stateAfter = "starting",
                result = "allowed",
                reason = "voice_gate_passed"
            )
        )
        val inputGeneration = voiceRecognizedInputDedupTracker.beginInput()
        internalLog(
            "VOICE_INPUT_DEDUP begin generation=$inputGeneration trigger=$trigger"
        )
        voiceDuplexCoordinator.startOpenListening()
    } }

    fun stopApiListening(preserveLateFinalGrace: Boolean = false) { with(viewModel) {
        callbacks.cancelAsrInputWatchdogs("stop_api_listening")
        voiceDuplexCoordinator.stopOpenListening(
            awaitLateFinal = preserveLateFinalGrace
        )
        if (backendSpeechFallbackActive) {
            backendSpeechFallbackActive = false
            liveSpeechClient.stop()
        }
        if (platformSpeechFallbackStarted) {
            platformSpeechFallbackStarted = false
            speechRecognizer.stop()
        }
    } }

    fun startTaskVoiceAsrSession(
        startReason: String,
        onEvent: (TaskVoiceAsrEvent) -> Unit,
        beforeStart: (() -> Unit)? = null
    ): Boolean = with(viewModel) {
        if (!qwenTaskVoiceEnabled) {
            internalLog(
                "VOICE_TASK_ASR backend provider disabled provider=$taskVoiceProvider " +
                    "reason=$startReason; using backend fallback"
            )
            callbacks.startBackendSpeechFallback()
            return false
        }
        beforeStart?.invoke()
        internalLog(
            "VOICE_TASK_ASR start provider=$taskVoiceProvider " +
                "reason=$startReason language=$voiceLanguageCode"
        )
        taskAsrClient.start(
            languageCode = voiceLanguageCode,
            startReason = startReason,
            onEvent = onEvent
        )
        true
    }

    fun startLiveTranscription() { with(viewModel) {
        internalLog(
            "startLiveTranscription redirected to task ASR " +
                "scene=${internalUiState.value.sceneType} dialogContext=${activeDialogContext != null}"
        )
        callbacks.startApiListening(VoiceListenTriggers.LiveTranscriptionRedirect)
        // Contact confirmation uses FOOD_ORDERING bot with server TTS trigger; ASR works there.
    } }

    fun stopLiveTranscription(suppressRestart: Boolean = true) { with(viewModel) {
        suppressAutoRestartOnClose = suppressRestart
        internalLog(
            "stopLiveTranscription runId=$activeDialogRunId suppressRestart=$suppressRestart " +
                "scene=${activeDialogContext?.sceneType} dialogKey=${activeDialogContext?.dialogKey}"
        )
        taskAsrClient.stop()
    } }

    fun ensureRealtimeSession(silentResume: Boolean = false) { with(viewModel) {
        internalLog("ensureRealtimeSession redirected to dialog ASR silentResume=$silentResume")
        if (isOutboundCallAudioSuppressed()) {
            voiceDuplexCoordinator.suspendDialogAudioForCall("ensure_realtime_session_call_active")
            return
        }
        if (activeInteractionChannel == InteractionChannel.VOICE &&
            !internalUiState.value.showAiCallPage &&
            !internalUiState.value.processingTurn
        ) {
            callbacks.startApiListening(VoiceListenTriggers.EnsureRealtimeSession)
        }
    } }

    private fun logVoiceListen(
        eventType: String,
        trigger: String,
        result: String,
        stateAfter: String? = null,
        reason: String? = null,
        callAudioSuppressed: Boolean
    ) { with(viewModel) {
        val state = internalUiState.value
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.ASR,
                eventType = eventType,
                sessionId = agentSessionId,
                taskId = state.taskId,
                callId = state.currentCallId,
                provider = taskVoiceProvider,
                trigger = trigger,
                stateBefore = voiceListenState(state),
                stateAfter = stateAfter,
                result = result,
                reason = reason,
                attributes = mapOf(
                    "callOutcomePending" to isCallOutcomePending(state).toString(),
                    "callAudioSuppressed" to callAudioSuppressed.toString(),
                    "voiceMode" to (activeInteractionChannel == InteractionChannel.VOICE).toString(),
                    "showAiCallPage" to state.showAiCallPage.toString()
                )
            )
        )
    } }

    private fun voiceListenState(state: Index9AssistantUiState): String =
        "listening=${state.listening},apiAsr=${state.apiAsrListening}," +
            "connecting=${state.voiceConnecting},processing=${state.processingTurn}"

    private fun isCallOutcomePending(state: Index9AssistantUiState): Boolean =
        state.processingTurn &&
            (state.status == CallOutcomePendingStatus ||
                state.callPageData.status == CallOutcomePendingStatus)

    private companion object {
        const val CallOutcomePendingStatus = "正在确认通话结果"
    }
}
