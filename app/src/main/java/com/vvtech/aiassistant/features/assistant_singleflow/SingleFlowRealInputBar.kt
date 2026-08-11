package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Send
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SfInputMode

@Composable
internal fun BoxScope.SingleFlowRealInputBar(
    assistantState: Index9AssistantUiState?,
    inputMode: SfInputMode,
    textInput: String,
    bottomOverlayInset: Dp,
    onInputModeChange: (SfInputMode) -> Unit,
    onTextInputChange: (String) -> Unit,
    onSubmitText: () -> Unit,
    onVoiceButtonTap: () -> Unit,
    onPauseTtsPlayback: (() -> Unit)?,
    onStopVoiceInteraction: (() -> Unit)?,
    onComposerHeightChanged: (Int) -> Unit
) {
    val state = assistantState
    val sfVoiceRecording = state?.voiceConnecting == true || state?.listening == true
    val sfApiTtsPlaying = state?.apiTtsPlaying ?: false
    val sfSendEnabled = textInput.trim().isNotEmpty()
    Column(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .imePadding()
            .padding(horizontal = 12.dp)
            .padding(top = 8.dp, bottom = 12.dp + bottomOverlayInset)
            .navigationBarsPadding()
            .onSizeChanged { onComposerHeightChanged(it.height) },
    ) {
        SingleFlowInputModeSwitcher(
            inputMode = inputMode,
            onInputModeChange = onInputModeChange
        )
        if (inputMode == SfInputMode.Voice) {
            SingleFlowPttInput(
                recording = sfVoiceRecording,
                ttsPlaying = sfApiTtsPlaying,
                onVoicePress = onVoiceButtonTap,
                onVoiceRelease = { onStopVoiceInteraction?.invoke() },
                onPauseTtsPlayback = onPauseTtsPlayback
            )
        } else {
            SingleFlowTextInput(
                textInput = textInput,
                recording = sfVoiceRecording,
                sendEnabled = sfSendEnabled,
                onTextInputChange = onTextInputChange,
                onSubmitText = onSubmitText
            )
        }
    }
}

@Composable
private fun SingleFlowInputModeSwitcher(
    inputMode: SfInputMode,
    onInputModeChange: (SfInputMode) -> Unit
) {
    Row(
        modifier = Modifier.padding(bottom = 8.dp),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp)
    ) {
        listOf(SfInputMode.Voice to "语音", SfInputMode.Text to "文字").forEach { (mode, label) ->
            Surface(
                modifier = Modifier.clickable { onInputModeChange(mode) },
                color = if (inputMode == mode) Color(0x1A0A84FF) else Color.Transparent,
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, if (inputMode == mode) Color(0xFF0A84FF) else Color(0xFFE3EAF3)),
                elevation = 0.dp
            ) {
                Text(
                    text = label,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    color = if (inputMode == mode) Color(0xFF0A84FF) else Color(0xFF667085),
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun SingleFlowPttInput(
    recording: Boolean,
    ttsPlaying: Boolean,
    onVoicePress: () -> Unit,
    onVoiceRelease: () -> Unit,
    onPauseTtsPlayback: (() -> Unit)?
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .pointerInput(recording, ttsPlaying) {
                detectTapGestures(
                    onPress = {
                        if (ttsPlaying) {
                            onPauseTtsPlayback?.invoke()
                            return@detectTapGestures
                        }
                        onVoicePress()
                        tryAwaitRelease()
                        onVoiceRelease()
                    }
                )
            },
        color = if (recording) Color(0xFFFFF1F0) else Color.White,
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, if (recording) Color(0xFFFF6B6B) else Color(0xFFE3EAF3)),
        elevation = 0.dp
    ) {
        Text(
            text = when {
                ttsPlaying -> "点击暂停"
                recording -> "松开结束"
                else -> "按住说话"
            },
            modifier = Modifier.padding(vertical = 15.dp),
            color = if (recording) Color(0xFFE14D46) else Color(0xFF344054),
            fontSize = 15.sp,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

@Composable
private fun SingleFlowTextInput(
    textInput: String,
    recording: Boolean,
    sendEnabled: Boolean,
    onTextInputChange: (String) -> Unit,
    onSubmitText: () -> Unit
) {
    val focusManager = LocalFocusManager.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Surface(
            modifier = Modifier.weight(1f),
            color = Color.White,
            shape = RoundedCornerShape(24.dp),
            border = BorderStroke(1.dp, Color(0xFFE3EAF3)),
            elevation = 0.dp
        ) {
            BasicTextField(
                value = textInput,
                onValueChange = if (recording) {
                    { _: String -> }
                } else {
                    onTextInputChange
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                textStyle = androidx.compose.ui.text.TextStyle(
                    color = Color(0xFF111827),
                    fontSize = 15.sp
                ),
                singleLine = true,
                readOnly = recording,
                keyboardActions = KeyboardActions(
                    onSend = {
                        if (sendEnabled) {
                            onSubmitText()
                            focusManager.clearFocus()
                        }
                    }
                ),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Text,
                    capitalization = KeyboardCapitalization.Sentences,
                    imeAction = ImeAction.Send
                ),
                decorationBox = { inner ->
                    if (textInput.isBlank() && !recording) {
                        Text(
                            text = "说点什么...",
                            color = Color(0xFFA0A8B4),
                            fontSize = 15.sp
                        )
                    }
                    inner()
                }
            )
        }
        Spacer(modifier = Modifier.width(10.dp))
        Surface(
            modifier = Modifier
                .size(48.dp)
                .clickable(enabled = sendEnabled) {
                    onSubmitText()
                    focusManager.clearFocus()
                },
            shape = CircleShape,
            color = Color.Transparent,
            elevation = 0.dp
        ) {
            val buttonColor = when {
                sendEnabled -> Brush.verticalGradient(listOf(Color(0xFF0A84FF), Color(0xFF0071EB)))
                else -> Brush.verticalGradient(listOf(Color(0xFFE3EAF3), Color(0xFFD6DEE8)))
            }
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(buttonColor, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.Send,
                    contentDescription = "发送",
                    tint = if (sendEnabled) Color.White else Color(0xFF98A2B3),
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}
