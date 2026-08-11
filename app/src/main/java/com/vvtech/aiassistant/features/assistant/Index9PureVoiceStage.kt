package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.RadioButton
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardVoice
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrBinding
import com.vvtech.aiassistant.features.assistant_tasks.looksLikeTerminalCallResultStatus
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames

// ─── Voice states derived from listening / processingTurn / status ───

internal enum class PureVoiceState { Standby, Listening, AiSpeaking, AiThinking }

private fun derivePureVoiceState(
    listening: Boolean,
    processingTurn: Boolean,
    aiSpeaking: Boolean
): PureVoiceState = when {
    listening -> PureVoiceState.Listening
    aiSpeaking -> PureVoiceState.AiSpeaking
    processingTurn -> PureVoiceState.AiThinking
    else -> PureVoiceState.Standby
}

// ─── Color constants ───

internal val VoiceBlue = Color(0xFF007AFF)
internal val VoiceGreen = Color(0xFF34C759)
internal val GlowBlue = Color(0x38007AFF)
internal val GlowGreen = Color(0x38349F59)

// ─── Button / icon sizes (60% of original 140dp) ───

internal val BtnSize = 84.dp
internal val GlowSize = 108.dp
internal val MicIconSize = 32.dp
internal val StopSquareSize = 26.dp

// ════════════════════════════════════════════════════════
//  PureVoiceStage — Clarifying stage, big circle button
// ════════════════════════════════════════════════════════

internal data class PureVoiceStageArgs(
    val modifier: Modifier = Modifier,
    val voiceLanguage: VoiceLanguage = VoiceLanguage.Chinese,
    val indicatorHorizontalPadding: Dp = 22.dp,
    val threadHorizontalPadding: Dp = 18.dp,
    val listening: Boolean,
    val processingTurn: Boolean,
    val aiSpeaking: Boolean,
    val manuallyPaused: Boolean = false,
    val liveUserTranscript: String? = null,
    val liveAssistantTranscript: String? = null,
    val status: String = "",
    val sceneType: String? = null,
    val clarificationSteps: List<ClarificationStep> = emptyList(),
    val summary: SummaryData? = null,
    val error: String? = null,
    val precheck: PureVoicePrecheckUiState? = null,
    val ocrBinding: PureVoiceOcrBinding,
    val callPageData: CallPageData? = null,
    val showCallPage: Boolean = false,
    val agentOptions: OptionsPayload? = null,
    val onAgentOptionSelect: (Int) -> Unit = {},
    val bottomControlMode: PureVoiceBottomControlMode? = null,
    val inputMode: SfInputMode = SfInputMode.Voice,
    val textInput: String = "",
    val activeCallModelTitle: String = AssistantCallModelDisplayNames.Qwen,
    val onInputModeChange: (SfInputMode) -> Unit = {},
    val onOpenCallModelSheet: () -> Unit = {},
    val onTextInputChange: (String) -> Unit = {},
    val onSubmitText: () -> Unit = {},
    val onMicClick: () -> Unit,
    val onStop: () -> Unit,
    val onMicCancel: () -> Unit = {},
    val onMicTooShort: () -> Unit = {}
)

@Composable
internal fun PureVoiceStage(args: PureVoiceStageArgs) {
    val bottomControlMode = args.bottomControlMode ?: if (args.manuallyPaused) {
        PureVoiceBottomControlMode.Mic
    } else if (args.listening) {
        PureVoiceBottomControlMode.Recording
    } else if (args.processingTurn || args.aiSpeaking) {
        PureVoiceBottomControlMode.Stop
    } else {
        PureVoiceBottomControlMode.Mic
    }
    val vstate = if (bottomControlMode == PureVoiceBottomControlMode.Ended || args.manuallyPaused) {
        PureVoiceState.Standby
    } else {
        derivePureVoiceState(args.listening, args.processingTurn, args.aiSpeaking)
    }
    PureVoiceStreamingStageContent(
        PureVoiceStageContentArgs(
            modifier = args.modifier,
            voiceLanguage = args.voiceLanguage,
            indicatorHorizontalPadding = args.indicatorHorizontalPadding,
            threadHorizontalPadding = args.threadHorizontalPadding,
            state = vstate,
            processingTurn = args.processingTurn,
            liveUserTranscript = args.liveUserTranscript,
            liveAssistantTranscript = args.liveAssistantTranscript,
            status = args.status,
            sceneType = args.sceneType,
            clarificationSteps = args.clarificationSteps,
            summary = args.summary,
            error = args.error,
            precheck = args.precheck,
            ocrBinding = args.ocrBinding,
            callPageData = args.callPageData,
            showCallPage = args.showCallPage,
            agentOptions = args.agentOptions,
            onAgentOptionSelect = args.onAgentOptionSelect,
            bottomControlMode = bottomControlMode,
            inputMode = args.inputMode,
            textInput = args.textInput,
            activeCallModelTitle = args.activeCallModelTitle,
            onInputModeChange = args.onInputModeChange,
            onOpenCallModelSheet = args.onOpenCallModelSheet,
            onTextInputChange = args.onTextInputChange,
            onSubmitText = args.onSubmitText,
            onMicClick = args.onMicClick,
            onStop = args.onStop,
            onMicCancel = args.onMicCancel,
            onMicTooShort = args.onMicTooShort
        )
    )
}
//  PureVoiceStreamingStageContent — v4.15 streaming voice surface
// ════════════════════════════════════════════════════════
