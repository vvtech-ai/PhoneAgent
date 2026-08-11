package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.material.icons.rounded.KeyboardVoice
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
@Composable
internal fun PureVoiceLiveIndicator(text: String, completed: Boolean, horizontalPadding: Dp) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = horizontalPadding, end = horizontalPadding, top = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        val transition = rememberInfiniteTransition(label = "pvLiveDot")
        val dotAlpha by transition.animateFloat(
            initialValue = 1f,
            targetValue = 0.3f,
            animationSpec = infiniteRepeatable(
                animation = tween(900),
                repeatMode = RepeatMode.Reverse
            ),
            label = "dotAlpha"
        )
        Box(
            modifier = Modifier
                .size(8.dp)
                .alpha(if (completed) 1f else dotAlpha)
                .clip(CircleShape)
                .background(if (completed) VoiceGreen else Color(0xFF2196F3))
        )
        Text(
            text = text,
            color = Color(0xFF2196F3),
            fontSize = 12.sp,
            lineHeight = 17.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
internal fun PureVoiceAiStateVisual(state: PureVoiceState) {
    val transition = rememberInfiniteTransition(label = "pvWave")
    if (state == PureVoiceState.AiThinking) return
    val scaleA by transition.animateFloat(
        initialValue = 0.78f,
        targetValue = when (state) {
            PureVoiceState.AiThinking -> 1.35f
            PureVoiceState.AiSpeaking -> 1.28f
            PureVoiceState.Listening -> 1.14f
            PureVoiceState.Standby -> 1f
        },
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = when (state) {
                    PureVoiceState.AiThinking -> 420
                    PureVoiceState.AiSpeaking -> 520
                    PureVoiceState.Listening -> 760
                    PureVoiceState.Standby -> 1200
                }
            ),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scaleA"
    )
    val scaleB by transition.animateFloat(
        initialValue = 0.9f,
        targetValue = when (state) {
            PureVoiceState.AiThinking -> 1.22f
            PureVoiceState.AiSpeaking -> 1.18f
            PureVoiceState.Listening -> 1.08f
            PureVoiceState.Standby -> 1f
        },
        animationSpec = infiniteRepeatable(
            animation = tween(640, delayMillis = 90),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scaleB"
    )
    val barColor = when (state) {
        PureVoiceState.AiSpeaking -> VoiceGreen
        else -> Color(0xFF0A84FF)
    }
    val glowColor = when (state) {
        PureVoiceState.AiSpeaking -> Color(0x2E34C759)
        else -> Color(0x2E0A84FF)
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp, bottom = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Box(modifier = Modifier.size(72.dp), contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .drawBehind {
                        drawCircle(
                            brush = Brush.radialGradient(
                                colors = listOf(glowColor, Color.Transparent),
                                center = Offset(size.width / 2, size.height / 2),
                                radius = size.width / 2
                            )
                        )
                    }
            )
            Row(
                modifier = Modifier
                    .width(52.dp)
                    .height(52.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                val heights = listOf(8, 13, 22, 34, 52, 34, 22, 13, 8)
                heights.forEachIndexed { index, height ->
                    val scale = when (index % 3) {
                        0 -> scaleA
                        1 -> scaleB
                        else -> (scaleA + scaleB) / 2f
                    }
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(height.dp)
                            .graphicsLayer(scaleY = if (state == PureVoiceState.Standby) 1f else scale)
                            .clip(RoundedCornerShape(999.dp))
                            .background(
                                if (state == PureVoiceState.AiThinking) {
                                    Brush.verticalGradient(
                                        listOf(Color(0xFF7B61FF), Color(0xFF0A84FF), Color(0xFF22D3EE))
                                    )
                                } else {
                                    Brush.verticalGradient(listOf(barColor, barColor))
                                }
                            )
                    )
                }
            }
        }
    }
}

@Composable
internal fun PureVoiceBottomControl(
    mode: PureVoiceBottomControlMode,
    voiceLanguage: VoiceLanguage,
    onPress: () -> Unit,
    onRelease: () -> Unit,
    onCancel: () -> Unit,
    onTooShort: () -> Unit
) {
    val finalizing = mode == PureVoiceBottomControlMode.Finalizing
    val ended = mode == PureVoiceBottomControlMode.Ended
    val enabled = !ended && !finalizing
    val currentMode by rememberUpdatedState(mode)
    val currentOnPress by rememberUpdatedState(onPress)
    val currentOnRelease by rememberUpdatedState(onRelease)
    val currentOnCancel by rememberUpdatedState(onCancel)
    val currentOnTooShort by rememberUpdatedState(onTooShort)
    val recording = mode == PureVoiceBottomControlMode.Recording
    val cancelDistancePx = with(LocalDensity.current) { 58.dp.toPx() }
    var cancelArmed by remember { mutableStateOf(false) }
    var transientHint by remember { mutableStateOf<String?>(null) }
    val hintText = when {
        cancelArmed -> pureVoicePttCancelHint(voiceLanguage)
        transientHint != null -> transientHint
        recording -> pureVoicePttSendHint(voiceLanguage)
        else -> null
    }
    LaunchedEffect(transientHint) {
        if (transientHint != null) {
            delay(1200L)
            transientHint = null
        }
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 22.dp),
        contentAlignment = Alignment.Center
    ) {
        PureVoiceBottomControlHint(text = hintText.orEmpty(), visible = hintText != null)
        Surface(
            modifier = Modifier
                .size(56.dp)
                .semantics {
                    if (finalizing) {
                        contentDescription = "识别中"
                        stateDescription = "识别中"
                        disabled()
                    }
                }
                .pointerInput(enabled, cancelDistancePx) {
                    if (!enabled) {
                        return@pointerInput
                    }
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        val pressedMode = currentMode
                        val startPosition = down.position
                        val startTime = down.uptimeMillis
                        cancelArmed = false
                        transientHint = null
                        if (pressedMode != PureVoiceBottomControlMode.Stop) {
                            currentOnPress()
                        }
                        var shouldStop = pressedMode == PureVoiceBottomControlMode.Stop
                        var shouldCancel = false
                        var shouldRejectShortPress = false
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == down.id }
                                ?: event.changes.firstOrNull()
                                ?: continue
                            val dragOffset = change.position - startPosition
                            cancelArmed = pressedMode != PureVoiceBottomControlMode.Stop &&
                                dragOffset.y <= -cancelDistancePx
                            if (!change.pressed) {
                                if (pressedMode != PureVoiceBottomControlMode.Stop) {
                                    val durationMillis = change.uptimeMillis - startTime
                                    shouldCancel = dragOffset.y <= -cancelDistancePx
                                    shouldRejectShortPress =
                                        !shouldCancel && durationMillis < 100L
                                }
                                break
                            }
                        }
                        cancelArmed = false
                        when {
                            shouldStop -> currentOnRelease()
                            shouldCancel -> {
                                transientHint = pureVoicePttCancelledHint(voiceLanguage)
                                currentOnCancel()
                            }
                            shouldRejectShortPress -> {
                                transientHint = pureVoicePttNoSpeechHint(voiceLanguage)
                                currentOnTooShort()
                            }
                            else -> currentOnRelease()
                        }
                    }
                },
            shape = CircleShape,
            color = Color.Transparent,
            elevation = 0.dp
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        brush = Brush.linearGradient(
                            if (ended) {
                                listOf(Color(0xFF8E99A8), Color(0xFF6F7A88))
                            } else if (recording) {
                                listOf(Color(0xFFFF5A52), Color(0xFFE53935))
                            } else {
                                listOf(Color(0xFF2196F3), Color(0xFF1976D2))
                            }
                        ),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                when (mode) {
                    PureVoiceBottomControlMode.Mic -> Icon(
                        imageVector = Icons.Rounded.KeyboardVoice,
                        contentDescription = "Hold to speak",
                        tint = Color.White,
                        modifier = Modifier.size(25.dp)
                    )

                    PureVoiceBottomControlMode.Recording -> Icon(
                        imageVector = Icons.Rounded.KeyboardVoice,
                        contentDescription = "Release to send",
                        tint = Color.White,
                        modifier = Modifier.size(25.dp)
                    )

                    PureVoiceBottomControlMode.Finalizing -> PureVoiceAsrFinalizingDots()

                    PureVoiceBottomControlMode.Stop -> Icon(
                        imageVector = Icons.Rounded.Stop,
                        contentDescription = "Stop current turn",
                        tint = Color.White,
                        modifier = Modifier.size(25.dp)
                    )

                    PureVoiceBottomControlMode.Ended -> Text(
                        text = "已终止",
                        color = Color.White,
                        fontSize = 12.sp,
                        lineHeight = 14.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

@Composable
private fun PureVoiceAsrFinalizingDots() {
    val transition = rememberInfiniteTransition(label = "pureVoiceAsrFinalizing")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 900, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "pureVoiceAsrFinalizingPhase"
    )
    val liftPx = with(LocalDensity.current) { 4.dp.toPx() }
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        repeat(3) { index ->
            val shiftedPhase = (phase - index * (1f / 6f) + 1f) % 1f
            val liftFraction = when {
                shiftedPhase < .3f -> shiftedPhase / .3f
                shiftedPhase < .6f -> (.6f - shiftedPhase) / .3f
                else -> 0f
            }
            Box(
                modifier = Modifier
                    .size(5.dp)
                    .graphicsLayer {
                        translationY = -liftPx * liftFraction
                        alpha = .46f + .54f * liftFraction
                    }
                    .background(Color.White, CircleShape)
            )
        }
    }
}

@Composable
private fun BoxScope.PureVoiceBottomControlHint(text: String, visible: Boolean) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = Modifier
            .align(Alignment.Center)
            .offset(y = (-46).dp)
    ) {
        Surface(
            shape = RoundedCornerShape(999.dp),
            color = Color(0xFF2F3440),
            elevation = 2.dp
        ) {
            Text(
                text = text,
                color = Color.White,
                fontSize = 11.sp,
                lineHeight = 14.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
            )
        }
    }
}

private fun pureVoicePttSendHint(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Release to send"
    VoiceLanguage.Japanese -> "離すと送信"
    VoiceLanguage.Chinese -> "松开发送"
}

private fun pureVoicePttCancelHint(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Release to cancel"
    VoiceLanguage.Japanese -> "離すとキャンセル"
    VoiceLanguage.Chinese -> "松开取消"
}

private fun pureVoicePttCancelledHint(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Cancelled"
    VoiceLanguage.Japanese -> "キャンセルしました"
    VoiceLanguage.Chinese -> "已取消"
}

private fun pureVoicePttNoSpeechHint(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Didn't hear anything. Please try again."
    VoiceLanguage.Japanese -> "聞き取れませんでした。もう一度お試しください。"
    VoiceLanguage.Chinese -> "没听到声音，请再试一次"
}
