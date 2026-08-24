package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckDisplayStage
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckItemState
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_pure_voice.asSequentialDisplay
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrBinding
import com.vvtech.aiassistant.features.assistant_recording.PureVoiceCallRecordingPlaybackHost
import kotlinx.coroutines.delay

private const val PureVoicePrecheckNetworkStageMs = 300L
private const val PureVoicePrecheckModelStageMs = 350L
private const val PureVoicePrecheckOutboundStageMs = 350L
private const val PureVoicePrecheckPassedStageMs = 350L
private const val PureVoicePrecheckReleaseDelayMs = 150L
private const val PureVoicePrecheckPollMs = 80L

internal data class SingleFlowPureVoiceContentArgs(
    val entryKey: Long,
    val realFlowEnabled: Boolean,
    val assistantState: Index9AssistantUiState?,
    val inputMode: SfInputMode,
    val textInput: String,
    val activeCallModelTitle: String,
    val listening: Boolean,
    val mockAiSpeaking: Boolean,
    val voiceLanguage: VoiceLanguage,
    val pureVoicePrecheck: PureVoicePrecheckUiState?,
    val ocrBinding: PureVoiceOcrBinding,
    val showMockRestaurantOptions: Boolean,
    val restaurants: List<SfRestaurantOption>,
    val onInputModeChange: (SfInputMode) -> Unit,
    val onOpenCallModelSheet: () -> Unit,
    val onTextInputChange: (String) -> Unit,
    val onSubmitText: () -> Unit,
    val onVoiceButtonTap: () -> Unit,
    val onStop: () -> Unit,
    val onCancel: () -> Unit,
    val onTooShort: () -> Unit,
    val onSelectMockRestaurant: (SfRestaurantOption) -> Unit,
    val onAgentOptionSelect: (Int) -> Unit
)

@Composable
internal fun ColumnScope.SingleFlowPureVoiceContent(
    args: SingleFlowPureVoiceContentArgs
) = with(args) {
    PureVoiceCallRecordingPlaybackHost(hostKey = entryKey)
    val state = assistantState
    val pvManuallyPaused = if (realFlowEnabled) {
        state?.voiceManuallyPaused == true
    } else {
        !listening
    }
    val pvListening = if (realFlowEnabled) {
        resolvePureVoiceListeningState(
            manuallyPaused = pvManuallyPaused,
            voiceConnecting = state?.voiceConnecting == true,
            listening = state?.listening == true,
            apiAsrListening = state?.apiAsrListening == true
        )
    } else {
        listening
    }
    val pvProcessing = if (realFlowEnabled) {
        state?.processingTurn == true || state?.loading == true
    } else {
        false
    }
    val pvLiveUserTranscript = if (realFlowEnabled) {
        state?.liveUserTranscript?.trim()?.ifBlank { null }
    } else {
        null
    }
    val pvLiveAssistantTranscript = if (realFlowEnabled) {
        state?.liveAssistantTranscript
            ?.let { sanitizeUserFacingNetworkText(it, voiceLanguage) }
            ?.trim()
            ?.ifBlank { null }
    } else {
        null
    }
    val pvWelcomePromptVisible = pvLiveAssistantTranscript in setOf(
        voiceLanguage.firstWelcome,
        voiceLanguage.repeatWelcome,
        voiceLanguage.standbyText
    )
    val pvAiSpeaking = if (realFlowEnabled) {
        (state?.localTtsSpeaking == true || state?.apiTtsPlaying == true) && !pvWelcomePromptVisible
    } else {
        mockAiSpeaking
    }
    var precheckGateActive by remember(entryKey) { mutableStateOf(true) }
    var precheckStage by remember(entryKey) {
        mutableStateOf(PureVoicePrecheckDisplayStage.Network)
    }
    val latestPrecheck by rememberUpdatedState(pureVoicePrecheck)
    LaunchedEffect(entryKey) {
        precheckGateActive = latestPrecheck != null
        precheckStage = PureVoicePrecheckDisplayStage.Network
        if (latestPrecheck == null) {
            return@LaunchedEffect
        }
        delay(PureVoicePrecheckNetworkStageMs)
        while (latestPrecheck.isPrecheckBlocked()) {
            delay(PureVoicePrecheckPollMs)
        }
        precheckStage = PureVoicePrecheckDisplayStage.Model
        delay(PureVoicePrecheckModelStageMs)
        while (!latestPrecheck.isPrecheckModelReadyForOutbound()) {
            delay(PureVoicePrecheckPollMs)
        }
        precheckStage = PureVoicePrecheckDisplayStage.Outbound
        delay(PureVoicePrecheckOutboundStageMs)
        while (!latestPrecheck.isPrecheckReadyToPass()) {
            delay(PureVoicePrecheckPollMs)
        }
        precheckStage = PureVoicePrecheckDisplayStage.Passed
        delay(PureVoicePrecheckPassedStageMs)
        delay(PureVoicePrecheckReleaseDelayMs)
        precheckGateActive = false
    }
    val gatedPrecheck = pureVoicePrecheck?.let { precheck ->
        if (precheckGateActive) precheck.asSequentialDisplay(precheckStage) else precheck
    }

    PureVoiceStage(
        PureVoiceStageArgs(
        modifier = Modifier
            .fillMaxWidth()
            .weight(1f),
        voiceLanguage = voiceLanguage,
        indicatorHorizontalPadding = 2.dp,
        threadHorizontalPadding = 2.dp,
        listening = pvListening,
        processingTurn = pvProcessing,
        aiSpeaking = pvAiSpeaking,
        manuallyPaused = pvManuallyPaused,
        liveUserTranscript = pvLiveUserTranscript,
        liveAssistantTranscript = pvLiveAssistantTranscript,
        status = state?.status?.let { sanitizeUserFacingNetworkText(it, voiceLanguage) }.orEmpty(),
        sceneType = if (realFlowEnabled) state?.sceneType else null,
        clarificationSteps = if (realFlowEnabled) state?.clarificationSteps ?: emptyList() else emptyList(),
        summary = if (realFlowEnabled) state?.summary else null,
        error = if (realFlowEnabled) {
            state?.error?.takeIf { it.isNotBlank() }?.let { sanitizeUserFacingError(it, voiceLanguage) }
        } else {
            null
        },
        precheck = gatedPrecheck,
        ocrBinding = ocrBinding,
        callPageData = if (realFlowEnabled) state?.callPageData else null,
        showCallPage = realFlowEnabled && state?.showAiCallPage == true,
        agentOptions = if (realFlowEnabled) state?.agentOptions else null,
        onAgentOptionSelect = onAgentOptionSelect,
        inputMode = inputMode,
        textInput = textInput,
        activeCallModelTitle = activeCallModelTitle,
        onInputModeChange = onInputModeChange,
        onOpenCallModelSheet = onOpenCallModelSheet,
        onTextInputChange = onTextInputChange,
        onSubmitText = onSubmitText,
        bottomControlMode = if (realFlowEnabled && state != null) {
            resolveSingleFlowPureVoiceBottomControlMode(
                taskStatus = state.taskStatus,
                status = state.status,
                manuallyPaused = pvManuallyPaused,
                backgroundPaused = state.voiceBackgroundPaused,
                listening = pvListening,
                asrFinalizing = state.manualAsrFinalizing,
                processingTurn = pvProcessing,
                aiSpeaking = pvAiSpeaking
            )
        } else if (pvManuallyPaused) {
            PureVoiceBottomControlMode.Mic
        } else if (pvListening) {
            PureVoiceBottomControlMode.Recording
        } else if (pvProcessing || pvAiSpeaking) {
            PureVoiceBottomControlMode.Stop
        } else {
            PureVoiceBottomControlMode.Mic
        },
        onMicClick = onVoiceButtonTap,
        onStop = onStop,
        onMicCancel = onCancel,
        onMicTooShort = onTooShort
        )
    )

    if (showMockRestaurantOptions) {
        PvRestaurantOptionsCard(
            options = restaurants,
            onSelect = onSelectMockRestaurant
        )
    }
}

private fun PureVoicePrecheckUiState?.isPrecheckBlocked(): Boolean =
    this?.blocking == true

private fun PureVoicePrecheckUiState?.isPrecheckModelReadyForOutbound(): Boolean {
    val precheck = this ?: return true
    if (precheck.blocking) return false
    val modelItem = precheck.items.getOrNull(1) ?: return !precheck.visible
    return modelItem.state == PureVoicePrecheckItemState.Passed
}

private fun PureVoicePrecheckUiState?.isPrecheckReadyToPass(): Boolean {
    val precheck = this ?: return true
    return !precheck.visible && !precheck.blocking
}
