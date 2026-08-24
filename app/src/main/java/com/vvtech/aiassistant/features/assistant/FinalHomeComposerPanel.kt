package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun FinalComposerPanelV2(
    mode: ComposerMode,
    voiceRecording: Boolean,
    taskStarted: Boolean,
    textDraft: String,
    apiAsrPartialText: String? = null,
    apiTtsPlaying: Boolean = false,
    processingTurn: Boolean = false,
    modifier: Modifier = Modifier,
    onOpen: () -> Unit,
    onModeChange: (ComposerMode) -> Unit,
    onStartVoice: () -> Unit,
    onStopVoice: () -> Unit,
    onInterruptTts: () -> Unit = {},
    onTextDraftChange: (String) -> Unit,
    onSendText: () -> Unit,
    onStopTask: () -> Unit
) {
    val focusManager = LocalFocusManager.current
    val sendEnabled = textDraft.trim().isNotEmpty()

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onOpen)
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
                        .clickable(onClick = onStopTask),
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
                        label = stringResource(R.string.home_mode_voice),
                        selected = mode == ComposerMode.Voice,
                        onClick = { onModeChange(ComposerMode.Voice) }
                    )
                    FinalModeButton(
                        label = stringResource(R.string.home_mode_text),
                        selected = mode == ComposerMode.Text,
                        onClick = { onModeChange(ComposerMode.Text) }
                    )
                }
            }

            Text(
                text = if (taskStarted) {
                    stringResource(R.string.home_task_continue)
                } else {
                    stringResource(R.string.home_task_new)
                },
                modifier = Modifier.padding(start = 4.dp, bottom = 10.dp),
                color = Color(0xFF98A2B3),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            )

            if (mode == ComposerMode.Voice) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        val titleText = when {
                            apiTtsPlaying -> currentAppText("AI 播报中", "AI is speaking")
                            processingTurn -> currentAppText("AI 思考中...", "AI is thinking...")
                            voiceRecording -> apiAsrPartialText?.takeIf { it.isNotBlank() }
                                ?: currentAppText("正在收音...", "Listening...")
                            else -> currentAppText("点击麦克风开始", "Tap the microphone to start")
                        }
                        val subtitleText = when {
                            apiTtsPlaying -> currentAppText(
                                "点击暂停播报，继续后开始收音",
                                "Tap to pause playback; listening resumes afterward"
                            )
                            processingTurn -> currentAppText("请稍等", "Please wait")
                            voiceRecording -> currentAppText(
                                "再次点击结束本轮输入",
                                "Tap again to finish this input"
                            )
                            else -> currentAppText("可切换文字输入", "You can switch to text input")
                        }
                        Text(
                            text = titleText,
                            color = Color(0xFF111827),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = subtitleText,
                            modifier = Modifier.padding(top = 4.dp),
                            color = Color(0xFF667085),
                            fontSize = 13.sp,
                            lineHeight = 19.sp
                        )
                    }
                    Surface(
                        modifier = Modifier
                            .size(58.dp)
                            .clickable {
                                when {
                                    apiTtsPlaying -> onInterruptTts()
                                    voiceRecording -> onStopVoice()
                                    processingTurn -> Unit
                                    else -> onStartVoice()
                                }
                            },
                        color = Color.Transparent,
                        shape = RoundedCornerShape(20.dp),
                        elevation = 0.dp
                    ) {
                        val buttonGradient = if (apiTtsPlaying) {
                            Brush.verticalGradient(listOf(Color(0xFFFF6B6B), Color(0xFFEE5A24)))
                        } else {
                            Brush.verticalGradient(listOf(Color(0xFF0A84FF), Color(0xFF0071EB)))
                        }
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(buttonGradient, RoundedCornerShape(20.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            when {
                                apiTtsPlaying -> Box(
                                    modifier = Modifier
                                        .size(18.dp)
                                        .background(Color.White, RoundedCornerShape(3.dp))
                                )

                                processingTurn -> FinalVoiceWave()
                                voiceRecording -> FinalPauseGlyph()
                                else -> Icon(
                                    imageVector = Icons.Outlined.Mic,
                                    contentDescription = stringResource(R.string.home_voice_input_content_description),
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
                            value = textDraft,
                            onValueChange = onTextDraftChange,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            textStyle = TextStyle(
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
                                    if (sendEnabled) {
                                        onSendText()
                                        focusManager.clearFocus()
                                    }
                                }
                            ),
                            decorationBox = { inner ->
                                if (textDraft.isBlank()) {
                                    Text(
                                        text = if (taskStarted) {
                                            "继续补充任务内容"
                                        } else {
                                            "请输入任务内容"
                                        },
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
                            .clickable(enabled = sendEnabled) {
                                onSendText()
                                focusManager.clearFocus()
                            },
                        color = if (sendEnabled) Color(0x140A84FF) else Color(0x0A0A84FF),
                        shape = RoundedCornerShape(14.dp),
                        elevation = 0.dp
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Rounded.Send,
                                contentDescription = stringResource(R.string.home_send_content_description),
                                tint = if (sendEnabled) Color(0xFF0A84FF) else Color(0x993C6EAA),
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
