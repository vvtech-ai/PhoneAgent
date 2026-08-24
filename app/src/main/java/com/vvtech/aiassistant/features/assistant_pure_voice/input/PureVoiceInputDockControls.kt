package com.vvtech.aiassistant.features.assistant_pure_voice.input

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardVoice
import androidx.compose.material.icons.rounded.Send
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.PureVoiceBottomControl
import com.vvtech.aiassistant.features.assistant.PureVoiceBottomControlMode
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames

@Composable
internal fun PureVoiceDockModelSelector(title: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.clickable(onClick = onClick).padding(horizontal = 4.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = pureVoiceCallModelDisplayName(title),
            color = Color(0xFF5F6B7A),
            fontSize = 12.sp,
            lineHeight = 16.sp
        )
        Icon(
            imageVector = Icons.Rounded.KeyboardArrowDown,
            contentDescription = null,
            tint = Color(0xFF8A94A6),
            modifier = Modifier.size(16.dp)
        )
    }
}

@Composable
internal fun PureVoiceModeDock(
    state: PureVoiceInputDockUiState,
    callbacks: PureVoiceInputDockCallbacks,
    onAddClick: () -> Unit,
    onSwitchToText: () -> Unit
) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(bottom = 2.dp),
        contentAlignment = Alignment.Center
    ) {
        PureVoiceBottomControl(
            mode = state.bottomControlMode,
            voiceLanguage = state.voiceLanguage,
            onPress = {
                if (state.bottomControlMode != PureVoiceBottomControlMode.Ended &&
                    state.bottomControlMode != PureVoiceBottomControlMode.Stop &&
                    state.bottomControlMode != PureVoiceBottomControlMode.Finalizing &&
                    !state.precheckBlocked
                ) callbacks.onMicClick()
            },
            onRelease = {
                if (state.bottomControlMode != PureVoiceBottomControlMode.Ended &&
                    state.bottomControlMode != PureVoiceBottomControlMode.Finalizing
                ) callbacks.onStop()
            },
            onCancel = {
                if (state.bottomControlMode != PureVoiceBottomControlMode.Ended &&
                    state.bottomControlMode != PureVoiceBottomControlMode.Finalizing
                ) callbacks.onMicCancel()
            },
            onTooShort = {
                if (state.bottomControlMode != PureVoiceBottomControlMode.Ended &&
                    state.bottomControlMode != PureVoiceBottomControlMode.Finalizing
                ) callbacks.onMicTooShort()
            }
        )
        PureVoiceDockIconButton(
            image = Icons.Rounded.Add,
            contentDescription = "Add image",
            modifier = Modifier.align(Alignment.CenterStart).padding(start = 20.dp),
            transparent = true,
            onClick = onAddClick
        )
        PureVoiceDockIconButton(
            image = Icons.Rounded.ChatBubbleOutline,
            contentDescription = "Switch to text input",
            modifier = Modifier.align(Alignment.CenterEnd).padding(end = 20.dp),
            transparent = true,
            onClick = onSwitchToText
        )
    }
}

@Composable
internal fun PureVoiceTextModeDock(
    state: PureVoiceInputDockUiState,
    callbacks: PureVoiceInputDockCallbacks,
    onAddClick: () -> Unit,
    onSwitchToVoice: () -> Unit
) {
    val canSend = state.textInput.trim().isNotEmpty()
    val showStop = state.bottomControlMode == PureVoiceBottomControlMode.Stop
    val focusManager = LocalFocusManager.current
    val submitText = {
        if (canSend) {
            callbacks.onSubmitText()
            focusManager.clearFocus()
        }
    }
    Row(
        modifier = Modifier.fillMaxWidth().height(88.dp).padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        PureVoiceDockIconButton(
            image = Icons.Rounded.Add,
            contentDescription = "Add image",
            transparent = true,
            onClick = onAddClick
        )
        Spacer(Modifier.width(8.dp))
        Surface(
            modifier = Modifier.weight(1f).height(48.dp),
            color = Color(0xFFF3F6FB),
            shape = RoundedCornerShape(24.dp),
            border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
            elevation = 0.dp
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                BasicTextField(
                    value = state.textInput,
                    onValueChange = callbacks.onTextInputChange,
                    modifier = Modifier.fillMaxWidth()
                        .padding(start = 16.dp, end = 80.dp, top = 13.dp, bottom = 13.dp),
                    textStyle = TextStyle(color = Color(0xFF111827), fontSize = 15.sp),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Text,
                        imeAction = ImeAction.Send
                    ),
                    keyboardActions = KeyboardActions(onSend = { submitText() }),
                    decorationBox = { inner ->
                        if (state.textInput.isBlank()) {
                            Text("Enter task details", color = Color(0xFFA0A8B4), fontSize = 15.sp)
                        }
                        inner()
                    }
                )
                Row(modifier = Modifier.align(Alignment.CenterEnd)) {
                    PureVoiceDockIconButton(
                        image = Icons.Rounded.KeyboardVoice,
                        contentDescription = "Switch to voice input",
                        transparent = true,
                        onClick = onSwitchToVoice
                    )
                    PureVoiceDockIconButton(
                        image = if (showStop) Icons.Rounded.Stop else Icons.Rounded.Send,
                        contentDescription = if (showStop) currentAppText("停止当前处理", "Stop current processing") else currentAppText("发送文字", "Send"),
                        enabled = showStop || canSend,
                        emphasized = true,
                        stop = showStop,
                        onClick = { if (showStop) callbacks.onStop() else submitText() }
                    )
                }
            }
        }
    }
}

@Composable
private fun PureVoiceDockIconButton(
    image: ImageVector,
    contentDescription: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    emphasized: Boolean = false,
    transparent: Boolean = false,
    stop: Boolean = false,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier.size(40.dp).clickable(enabled = enabled, onClick = onClick),
        color = when {
            transparent -> Color.Transparent
            !enabled -> Color(0xFFE3EAF3)
            stop -> Color(0xFFE7EAEE)
            emphasized -> Color(0xFF0A84FF)
            else -> Color.White
        },
        shape = CircleShape,
        border = if (transparent || emphasized || stop) null else BorderStroke(1.dp, Color(0xFFE3EAF3)),
        elevation = 0.dp
    ) {
        Icon(
            imageVector = image,
            contentDescription = contentDescription,
            tint = when {
                !enabled -> Color(0xFF98A2B3)
                stop -> Color(0xFF475467)
                emphasized -> Color.White
                else -> Color(0xFF0F172A)
            },
            modifier = Modifier.padding(10.dp)
        )
    }
}

private fun pureVoiceCallModelDisplayName(raw: String): String =
    AssistantCallModelDisplayNames.resolveOrDefault(raw)
