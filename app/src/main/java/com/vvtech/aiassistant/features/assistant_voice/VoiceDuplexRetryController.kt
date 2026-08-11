package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.localizedConnectingVoiceStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal interface VoiceDuplexRetryCallbacks {
    var dialogAsrActive: Boolean
    fun restoreNormalAudioMode(reason: String)
    fun startOpenListening()
}

internal class VoiceDuplexRetryController(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceDuplexRetryCallbacks
) {
    fun restartListeningAfterDroppedTranscript(reason: String) { with(viewModel) {
        val state = internalUiState.value
        callbacks.dialogAsrActive = false
        callbacks.restoreNormalAudioMode("unspecified")
        taskAsrClient.closeNow(reason)
        if (activeInteractionChannel != InteractionChannel.VOICE ||
            isOutboundCallAudioSuppressed() ||
            state.processingTurn ||
            state.voiceManuallyPaused ||
            state.voiceBackgroundPaused ||
            state.showAiCallPage ||
            state.summary != null ||
            state.selectionSheet != null ||
            state.agentCallResult != null
        ) {
            internalLog(
                "VOICE_DUPLEX dropped transcript no resume reason=$reason " +
                    "processing=${state.processingTurn} paused=${state.voiceManuallyPaused || state.voiceBackgroundPaused}"
            )
            internalUiState.update {
                it.copy(
                    listening = false,
                    voiceConnecting = false,
                    apiAsrListening = false,
                    apiAsrPartialText = null,
                    liveUserTranscript = null
                )
            }
            return
        }
        internalLog("VOICE_DUPLEX restart listening after dropped transcript reason=$reason")
        internalUiState.update {
            it.copy(
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                voiceConnecting = true,
                listening = false,
                status = localizedConnectingVoiceStatus()
            )
        }
        if (activeInteractionChannel == InteractionChannel.VOICE &&
            internalUiState.value.agentCallResult == null
        ) {
            viewModelScope.launch {
                delay(RestartAfterStopDelayMs)
                if (activeInteractionChannel == InteractionChannel.VOICE &&
                    internalUiState.value.voiceConnecting &&
                    !internalUiState.value.apiTtsPlaying &&
                    !isOutboundCallAudioSuppressed() &&
                    internalUiState.value.agentCallResult == null
                ) {
                    callbacks.startOpenListening()
                }
            }
        }
    } }

    private companion object {
        const val RestartAfterStopDelayMs = 250L
    }
}
