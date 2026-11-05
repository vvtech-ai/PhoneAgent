package com.vvtech.aiassistant.uireference

import com.vvtech.aiassistant.features.assistant_pure_voice.input.NativeDockModelCapsule
import com.vvtech.aiassistant.features.assistant_pure_voice.input.NativeKeyboardSwitchButton
import com.vvtech.aiassistant.features.assistant_pure_voice.input.NativeDockIconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.runtime.Composable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import com.vvtech.aiassistant.features.assistant.PureVoiceAiStateVisual
import com.vvtech.aiassistant.features.assistant.PureVoiceState
import com.vvtech.aiassistant.features.assistant.PureVoiceBottomControl
import com.vvtech.aiassistant.features.assistant.PureVoiceBottomControlMode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.SingleFlowHeader

/** Actual native header; synthetic stage, empty close action, no session or SDK. */
@Composable
internal fun ConversationHeaderReference(stage: Int = 1, showWave: Boolean = false, showModel: Boolean = false, showFinalizing: Boolean = false, waveState: PureVoiceState = PureVoiceState.Standby) {
    Column(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
            .padding(horizontal = 16.dp).statusBarsPadding().padding(top = 14.dp)
    ) {
        SingleFlowHeader(stage = stage, closeTaskAction = {})
        if (showFinalizing) Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
            PureVoiceBottomControl(
                mode = PureVoiceBottomControlMode.Finalizing, voiceLanguage = VoiceLanguage.Chinese,
                onPress = {}, onRelease = {}, onCancel = {},
                touchTargetSize = 60.dp, topPadding = 0.dp, bottomPadding = 0.dp
            )
        }
        if (showModel) Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
            Column(Modifier.padding(horizontal = 2.dp)) {
                NativeDockModelCapsule(title = "QwenOmniPlus", billingMultiplier = null, onClick = {}, horizontalPadding = 12.dp)
                Spacer(Modifier.height(8.dp))
                Box(Modifier.fillMaxWidth().height(72.dp), contentAlignment = Alignment.Center) {
                    NativeDockIconButton(image = Icons.Rounded.Add, contentDescription = "添加图片",
                        modifier = Modifier.align(Alignment.CenterStart).padding(start = 18.dp), transparent = true, onClick = {})
                    PureVoiceBottomControl(mode = PureVoiceBottomControlMode.Mic, voiceLanguage = VoiceLanguage.Chinese,
                        onPress = {}, onRelease = {}, onCancel = {}, touchTargetSize = 60.dp, topPadding = 0.dp, bottomPadding = 0.dp)
                    NativeKeyboardSwitchButton(contentDescription = "切换到文字输入",
                        modifier = Modifier.align(Alignment.CenterEnd).padding(end = 20.dp), onClick = {})
                }
            }
        }
        if (showWave) Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
            PureVoiceAiStateVisual(state = waveState)
        }
    }
}
