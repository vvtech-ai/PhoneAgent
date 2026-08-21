package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.rounded.Send
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalModeButton
import com.vvtech.aiassistant.features.assistant.FinalPauseGlyph
import com.vvtech.aiassistant.features.assistant.SfInputMode
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun BoxScope.SingleFlowDemoInputPanel(
    inputMode: SfInputMode,
    textInput: String,
    listening: Boolean,
    bottomOverlayInset: Dp,
    onInputModeChange: (SfInputMode) -> Unit,
    onTextInputChange: (String) -> Unit,
    onSubmitText: () -> Unit,
    onVoiceButtonTap: () -> Unit,
    onStopClick: () -> Unit,
    onComposerHeightChanged: (Int) -> Unit
) {
    val focusManager = LocalFocusManager.current
    val sfSendEnabled = textInput.trim().isNotEmpty()
    Surface(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 12.dp + bottomOverlayInset)
            .navigationBarsPadding()
            .imePadding()
            .onSizeChanged { onComposerHeightChanged(it.height) }
            .shadow(
                elevation = 18.dp,
                shape = RoundedCornerShape(26.dp),
                ambientColor = Color(0x1F101114),
                spotColor = Color(0x1F101114)
            ),
        color = Color.White.copy(alpha = 0.82f),
        shape = RoundedCornerShape(26.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.80f)),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    modifier = Modifier
                        .size(30.dp)
                        .clickable(onClick = onStopClick),
                    color = Color(0x14111111),
                    shape = RoundedCornerShape(9.dp),
                    elevation = 0.dp
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Box(
                            modifier = Modifier
                                .size(11.dp)
                                .background(Color(0xDB111111), RoundedCornerShape(3.dp))
                        )
                    }
                }

                Row(
                    modifier = Modifier
                        .shadow(
                            elevation = 10.dp,
                            shape = RoundedCornerShape(18.dp),
                            ambientColor = Color(0x0D000000),
                            spotColor = Color(0x0D000000)
                        )
                        .clip(RoundedCornerShape(18.dp))
                        .background(Color.White.copy(alpha = 0.64f))
                        .border(BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)), RoundedCornerShape(18.dp))
                        .padding(4.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    FinalModeButton(
                        label = "Voice",
                        selected = inputMode == SfInputMode.Voice,
                        onClick = { onInputModeChange(SfInputMode.Voice) }
                    )
                    FinalModeButton(
                        label = "Text",
                        selected = inputMode == SfInputMode.Text,
                        onClick = { onInputModeChange(SfInputMode.Text) }
                    )
                }
            }

            if (inputMode == SfInputMode.Voice) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = if (listening) {
                                currentAppText("正在收音...", "Listening...")
                            } else {
                                currentAppText("点击麦克风开始", "Tap the mic to start")
                            },
                            color = Color(0xFF111827),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = if (listening) {
                                currentAppText("再次点击结束", "Tap again to stop")
                            } else {
                                currentAppText("可切换文字输入", "You can switch to text input")
                            },
                            modifier = Modifier.padding(top = 4.dp),
                            color = Color(0xFF667085),
                            fontSize = 13.sp,
                            lineHeight = 19.sp
                        )
                    }
                    Surface(
                        modifier = Modifier
                            .size(58.dp)
                            .clickable(onClick = onVoiceButtonTap),
                        color = Color.Transparent,
                        shape = RoundedCornerShape(20.dp),
                        elevation = 0.dp
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    Brush.verticalGradient(listOf(Color(0xFF0A84FF), Color(0xFF0071EB))),
                                    RoundedCornerShape(20.dp)
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            if (listening) {
                                FinalPauseGlyph()
                            } else {
                                Icon(
                                    imageVector = Icons.Outlined.Mic,
                                    contentDescription = "Voice input",
                                    tint = Color.White,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        }
                    }
                }
            } else {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        modifier = Modifier.weight(1f),
                        color = Color.White,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, Color(0xFFE3EAF3)),
                        elevation = 0.dp
                    ) {
                        BasicTextField(
                            value = textInput,
                            onValueChange = onTextInputChange,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            textStyle = androidx.compose.ui.text.TextStyle(
                                color = Color(0xFF111827),
                                fontSize = 15.sp
                            ),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Text,
                                capitalization = KeyboardCapitalization.Sentences,
                                imeAction = ImeAction.Send
                            ),
                            keyboardActions = KeyboardActions(
                                onSend = {
                                    if (sfSendEnabled) {
                                        onSubmitText()
                                        focusManager.clearFocus()
                                    }
                                }
                            ),
                            decorationBox = { inner ->
                                if (textInput.isBlank()) {
                                    Text(
                                        text = "Enter task details",
                                        color = Color(0xFF98A2B3),
                                        fontSize = 14.sp
                                    )
                                }
                                inner()
                            }
                        )
                    }
                    Surface(
                        modifier = Modifier
                            .size(48.dp)
                            .clickable(enabled = sfSendEnabled) {
                                onSubmitText()
                                focusManager.clearFocus()
                            },
                        color = if (sfSendEnabled) Color(0x140A84FF) else Color(0x0A0A84FF),
                        shape = RoundedCornerShape(14.dp),
                        elevation = 0.dp
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Rounded.Send,
                                contentDescription = "Send",
                                tint = if (sfSendEnabled) Color(0xFF0A84FF) else Color(0x993C6EAA),
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
