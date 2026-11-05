package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import com.vvtech.aiassistant.features.assistant_singleflow.LocalSingleFlowBackgroundGeometry
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowBackgroundGeometry
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.PureVoiceStage
import com.vvtech.aiassistant.features.assistant.PureVoiceStageArgs
import com.vvtech.aiassistant.features.assistant.PureVoiceBottomControlMode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrBinding
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrCallbacks
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrUiState
import com.vvtech.aiassistant.features.assistant.SingleFlowHeader

/** Actual full header/stage with synthetic state and no business/SDK ports. */
@Composable
fun ConversationOpeningReference() {
    var geometry by remember { mutableStateOf(SingleFlowBackgroundGeometry()) }
    CompositionLocalProvider(LocalSingleFlowBackgroundGeometry provides geometry) {
    Column(Modifier.fillMaxSize()
        .onGloballyPositioned { coordinates ->
            val next = SingleFlowBackgroundGeometry(
                topInRootPx = coordinates.positionInRoot().y,
                heightPx = coordinates.size.height.toFloat().coerceAtLeast(1f))
            if (geometry != next) geometry = next
        }
        .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
        .padding(horizontal = 16.dp).statusBarsPadding().padding(top = 14.dp)) {
        SingleFlowHeader(stage = 1, closeTaskAction = {})
        PureVoiceStage(PureVoiceStageArgs(
            modifier = Modifier.fillMaxWidth().weight(1f),
            voiceLanguage = VoiceLanguage.Chinese,
            indicatorHorizontalPadding = 2.dp,
            threadHorizontalPadding = 2.dp,
            listening = false, processingTurn = false, aiSpeaking = false,
            manuallyPaused = true,
            clarificationSteps = listOf(ClarificationStep(role = VoiceRole.Assistant,
                text = "想订演示联系人？告诉我时间和人数就行，有其他要求也可以一起说。", status = "")),
            status = "按住按钮说话",
            ocrBinding = PureVoiceOcrBinding(PureVoiceOcrUiState(), PureVoiceOcrCallbacks(onImageSelected = {})),
            bottomControlMode = PureVoiceBottomControlMode.Mic,
            activeCallModelTitle = "QwenOmniPlus",
            onMicClick = {}, onStop = {}, onMicCancel = {}, onMicTooShort = {},
        ))
    }
    }
}
