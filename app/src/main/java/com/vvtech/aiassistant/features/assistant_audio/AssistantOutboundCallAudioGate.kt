package com.vvtech.aiassistant.features.assistant_audio

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.viewmodel.shouldSuppressDialogAudioForCall
import com.vvtech.aiassistant.logging.AppFileLogger

internal class AssistantOutboundCallAudioGate(
    private val viewModel: AssistantViewModel
) {
    fun isSuppressed(): Boolean =
        shouldSuppressDialogAudioForCall(
            showAiCallPage = viewModel.internalUiState.value.showAiCallPage,
            pendingAiCallLaunch = viewModel.pendingAiCallLaunch,
            outboundCallAudioSuppressed = viewModel.outboundCallAudioSuppressed,
            currentCallId = viewModel.internalUiState.value.currentCallId
        )

    fun snapshot(): String {
        val state = viewModel.internalUiState.value
        return "showAiCallPage=${state.showAiCallPage} " +
            "pendingAiCallLaunch=${viewModel.pendingAiCallLaunch} " +
            "outboundCallAudioSuppressed=${viewModel.outboundCallAudioSuppressed} " +
            "taskId=${state.taskId.orEmpty()} currentCallId=${state.currentCallId.orEmpty()} " +
            "processingTurn=${state.processingTurn} voiceConnecting=${state.voiceConnecting} " +
            "voiceActive=${state.voiceActive} listening=${state.listening} " +
            "apiAsrListening=${state.apiAsrListening} apiTtsPlaying=${state.apiTtsPlaying} " +
            "localTtsSpeaking=${state.localTtsSpeaking} voiceManuallyPaused=${state.voiceManuallyPaused} " +
            "voiceBackgroundPaused=${state.voiceBackgroundPaused}"
    }

    fun log(reason: String, suppressed: Boolean = isSuppressed()) {
        AppFileLogger.i(
            "CALL_AUDIO_GATE",
            "reason=$reason suppressed=$suppressed ${snapshot()}"
        )
    }

    fun beginSuppression(reason: String) {
        val alreadySuppressed = viewModel.outboundCallAudioSuppressed
        viewModel.outboundCallAudioSuppressed = true
        val state = viewModel.internalUiState.value
        val hasDialogAudio = viewModel.voiceDuplexCoordinator.dialogAsrActive ||
            state.apiAsrListening ||
            state.voiceConnecting ||
            state.voiceActive ||
            state.listening ||
            state.apiTtsPlaying ||
            state.localTtsSpeaking ||
            viewModel.localTtsPlaying ||
            viewModel.audioRecorder.isRecording()
        log(
            "begin_suppression:$reason alreadySuppressed=$alreadySuppressed hasDialogAudio=$hasDialogAudio"
        )
        if (!alreadySuppressed || hasDialogAudio) {
            viewModel.voiceDuplexCoordinator.suspendDialogAudioForCall(reason)
        }
    }

    fun endSuppression(reason: String) {
        if (viewModel.outboundCallAudioSuppressed) {
            viewModel.internalLog("endOutboundCallAudioSuppression reason=$reason")
        }
        viewModel.outboundCallAudioSuppressed = false
        log("end_suppression:$reason", suppressed = false)
    }
}
