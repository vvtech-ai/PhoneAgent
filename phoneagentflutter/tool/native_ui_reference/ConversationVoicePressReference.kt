package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.*

/** Actual pointer/feedback components only; all speech actions are empty. */
@Composable
fun ConversationVoicePressReference() {
    var feedback by remember { mutableStateOf(PureVoicePttFeedbackState()) }
    Column(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
            .padding(horizontal = 16.dp).statusBarsPadding().padding(top = 14.dp)
    ) {
        SingleFlowHeader(stage = 1, closeTaskAction = {})
        Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
            Box(Modifier.fillMaxWidth().height(72.dp), contentAlignment = Alignment.Center) {
                PureVoicePttFeedbackOverlay(
                    state = feedback,
                    anchorFromBottom = 36.dp,
                    modifier = Modifier.matchParentSize()
                )
                PureVoiceBottomControl(
                    mode = PureVoiceBottomControlMode.Mic,
                    voiceLanguage = VoiceLanguage.Chinese,
                    onPress = {}, onRelease = {}, onCancel = {},
                    touchTargetSize = 60.dp, topPadding = 0.dp, bottomPadding = 0.dp,
                    onFeedbackStateChange = { feedback = it }
                )
            }
        }
    }
}
