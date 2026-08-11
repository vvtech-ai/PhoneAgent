package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckItemState
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoiceTailFollowState
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoiceThreadList
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_pure_voice.buildPureVoiceThreadRenderState
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrBinding

internal data class PureVoiceStageContentArgs(
    val modifier: Modifier,
    val voiceLanguage: VoiceLanguage,
    val indicatorHorizontalPadding: Dp,
    val threadHorizontalPadding: Dp,
    val state: PureVoiceState,
    val processingTurn: Boolean,
    val liveUserTranscript: String?,
    val liveAssistantTranscript: String?,
    val status: String,
    val sceneType: String?,
    val clarificationSteps: List<ClarificationStep>,
    val summary: SummaryData?,
    val error: String?,
    val precheck: PureVoicePrecheckUiState?,
    val ocrBinding: PureVoiceOcrBinding,
    val callPageData: CallPageData?,
    val showCallPage: Boolean,
    val agentOptions: OptionsPayload?,
    val onAgentOptionSelect: (Int) -> Unit,
    val bottomControlMode: PureVoiceBottomControlMode,
    val inputMode: SfInputMode,
    val textInput: String,
    val activeCallModelTitle: String,
    val onInputModeChange: (SfInputMode) -> Unit,
    val onOpenCallModelSheet: () -> Unit,
    val onTextInputChange: (String) -> Unit,
    val onSubmitText: () -> Unit,
    val onMicClick: () -> Unit,
    val onStop: () -> Unit,
    val onMicCancel: () -> Unit,
    val onMicTooShort: () -> Unit
)

@Composable
internal fun PureVoiceStreamingStageContent(args: PureVoiceStageContentArgs) {
    val listState = rememberLazyListState()
    var threadViewportHeightPx by remember { mutableStateOf(0) }
    var recordingCardRevealEpoch by remember { mutableStateOf(0) }
    var tailFollowState by remember { mutableStateOf(PureVoiceTailFollowState()) }
    val precheckBlocked = args.precheck?.let { precheck ->
        precheck.visible && precheck.items.any { item ->
            item.state == PureVoicePrecheckItemState.Checking ||
                item.state == PureVoicePrecheckItemState.Blocked
        }
    } == true
    val renderState = buildPureVoiceThreadRenderState(
        voiceLanguage = args.voiceLanguage,
        state = args.state,
        processingTurn = args.processingTurn,
        liveUserTranscript = args.liveUserTranscript,
        liveAssistantTranscript = args.liveAssistantTranscript,
        status = args.status,
        clarificationSteps = args.clarificationSteps,
        error = args.error,
        precheck = args.precheck,
        callPageData = args.callPageData,
        showCallPage = args.showCallPage,
        ocrAttachments = args.ocrBinding.state.attachments,
    )

    LaunchedEffect(listState) {
        snapshotFlow { listState.isScrollInProgress to listState.canScrollForward }
            .collect { (isScrollInProgress, canScrollForward) ->
                tailFollowState = tailFollowState.onListSnapshot(
                    isScrollInProgress = isScrollInProgress,
                    canScrollForward = canScrollForward,
                )
            }
    }

    LaunchedEffect(renderState.scrollSignature, threadViewportHeightPx) {
        if (renderState.threadCount > 0 && threadViewportHeightPx > 0) {
            // The list owns one terminal anchor after all rendered thread content.
            listState.animateScrollToItem(renderState.threadCount)
        }
    }

    LaunchedEffect(recordingCardRevealEpoch) {
        if (
            recordingCardRevealEpoch > 0 &&
            tailFollowState.followingTail &&
            renderState.threadCount > 0 &&
            threadViewportHeightPx > 0
        ) {
            withFrameNanos { }
            if (tailFollowState.followingTail && !listState.isScrollInProgress) {
                listState.scrollToItem(renderState.threadCount)
            }
        }
    }

    Column(
        modifier = args.modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        PureVoiceLiveIndicator(
            text = renderState.liveText,
            completed = renderState.precheck == null &&
                (renderState.showCallResult || renderState.liveText.contains("完成")),
            horizontalPadding = args.indicatorHorizontalPadding
        )
        if (!args.showCallPage) {
            PureVoiceAiStateVisual(state = args.state)
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .onSizeChanged { threadViewportHeightPx = it.height }
        ) {
            PureVoiceThreadList(
                listState = listState,
                renderState = renderState,
                voiceLanguage = args.voiceLanguage,
                threadHorizontalPadding = args.threadHorizontalPadding,
                processingTurn = args.processingTurn,
                sceneType = args.sceneType,
                summary = args.summary,
                onRecordingCardRevealed = {
                    if (tailFollowState.followingTail && !listState.isScrollInProgress) {
                        recordingCardRevealEpoch += 1
                    }
                },
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .align(Alignment.TopCenter)
                    .background(
                        Brush.verticalGradient(
                            listOf(Color(0xFFF3F5F9), Color(0xB3F3F5F9), Color.Transparent)
                        )
                    )
            )
            args.agentOptions?.let { options ->
                PureVoiceAgentOptionsCard(
                    options = options,
                    onSelectIndex = args.onAgentOptionSelect,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                )
            }
        }
        PureVoiceInputModePanel(
            inputMode = args.inputMode,
            textInput = args.textInput,
            activeCallModelTitle = args.activeCallModelTitle,
            onInputModeChange = args.onInputModeChange,
            onOpenCallModelSheet = args.onOpenCallModelSheet,
            onTextInputChange = args.onTextInputChange,
            onSubmitText = args.onSubmitText,
            ocrBinding = args.ocrBinding,
            bottomControlMode = args.bottomControlMode,
            voiceLanguage = args.voiceLanguage,
            precheckBlocked = precheckBlocked,
            onMicClick = args.onMicClick,
            onStop = args.onStop,
            onMicCancel = args.onMicCancel,
            onMicTooShort = args.onMicTooShort
        )
    }
}
