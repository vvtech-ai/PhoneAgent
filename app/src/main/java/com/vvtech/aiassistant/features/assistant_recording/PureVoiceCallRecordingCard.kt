package com.vvtech.aiassistant.features.assistant_recording

import android.animation.ValueAnimator
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.sin

private val RecordingBlueStart = Color(0xFF0A84FF)
private val RecordingBlueEnd = Color(0xFF1677E8)

@Composable
internal fun PureVoiceCallRecordingCard(
    state: CallRecordingUiState,
    onTogglePlayback: () -> Unit,
) {
    val playing = state.playbackState == CallRecordingPlaybackState.Playing
    val controlIcon = state.controlIcon()
    val enabled = controlIcon != CallRecordingControlIcon.Loading
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Row(
            modifier = Modifier
                .widthIn(max = 270.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(
                    Brush.horizontalGradient(
                        listOf(RecordingBlueStart, RecordingBlueEnd),
                    )
                )
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "本次电话录音",
                    color = Color.White,
                    fontSize = 13.sp,
                    lineHeight = 17.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = state.displayDuration(),
                    modifier = Modifier.padding(top = 1.dp),
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 10.sp,
                    lineHeight = 13.sp,
                )
            }
            RecordingWaveform(playing = playing)
            RecordingPlayControl(
                icon = controlIcon,
                enabled = enabled,
                onClickLabel = state.controlClickLabel(),
                onClick = onTogglePlayback,
            )
        }
    }
}

@Composable
private fun RecordingPlayControl(
    icon: CallRecordingControlIcon,
    enabled: Boolean,
    onClickLabel: String,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier
            .size(38.dp)
            .clickable(
                enabled = enabled,
                role = Role.Button,
                onClickLabel = onClickLabel,
                onClick = onClick,
            ),
        shape = CircleShape,
        color = Color.White.copy(alpha = 0.2f),
    ) {
        Box(contentAlignment = Alignment.Center) {
            when (icon) {
                CallRecordingControlIcon.Loading -> CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    color = Color.White,
                    strokeWidth = 2.dp,
                )
                else -> Canvas(modifier = Modifier.size(18.dp)) {
                    when (icon) {
                        CallRecordingControlIcon.Pause -> {
                            val barWidth = size.width * 0.22f
                            drawRoundRect(
                                color = Color.White,
                                topLeft = Offset(size.width * 0.2f, size.height * 0.15f),
                                size = androidx.compose.ui.geometry.Size(
                                    barWidth,
                                    size.height * 0.7f,
                                ),
                            )
                            drawRoundRect(
                                color = Color.White,
                                topLeft = Offset(size.width * 0.58f, size.height * 0.15f),
                                size = androidx.compose.ui.geometry.Size(
                                    barWidth,
                                    size.height * 0.7f,
                                ),
                            )
                        }
                        CallRecordingControlIcon.Retry -> {
                            val strokeWidth = 2.dp.toPx()
                            drawArc(
                                color = Color.White,
                                startAngle = -62f,
                                sweepAngle = 292f,
                                useCenter = false,
                                topLeft = Offset(strokeWidth, strokeWidth),
                                size = androidx.compose.ui.geometry.Size(
                                    width = size.width - strokeWidth * 2,
                                    height = size.height - strokeWidth * 2,
                                ),
                                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                            )
                            val arrow = Path().apply {
                                moveTo(size.width * 0.63f, size.height * 0.08f)
                                lineTo(size.width * 0.91f, size.height * 0.08f)
                                lineTo(size.width * 0.91f, size.height * 0.36f)
                                close()
                            }
                            drawPath(arrow, Color.White)
                        }
                        CallRecordingControlIcon.Play -> {
                            val path = Path().apply {
                                moveTo(size.width * 0.3f, size.height * 0.18f)
                                lineTo(size.width * 0.78f, size.height * 0.5f)
                                lineTo(size.width * 0.3f, size.height * 0.82f)
                                close()
                            }
                            drawPath(path, Color.White)
                        }
                        CallRecordingControlIcon.Loading -> Unit
                    }
                }
            }
        }
    }
}

@Composable
private fun RecordingWaveform(playing: Boolean) {
    val animationsEnabled = ValueAnimator.areAnimatorsEnabled()
    val transition = rememberInfiniteTransition()
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 700, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
    )
    Canvas(modifier = Modifier.width(60.dp).height(28.dp)) {
        val bases = floatArrayOf(.24f, .45f, .7f, .42f, .82f, .55f, .34f, .74f, .5f, .28f, .6f, .36f)
        val gap = size.width / (bases.size - 1)
        bases.forEachIndexed { index, base ->
            val motion = if (playing && animationsEnabled) {
                0.72f + 0.28f * sin((phase * 2f * PI + index * 0.8f).toFloat())
            } else {
                1f
            }
            val barHeight = size.height * base * motion
            val x = index * gap
            drawLine(
                color = Color.White.copy(alpha = 0.9f),
                start = Offset(x, (size.height - barHeight) / 2f),
                end = Offset(x, (size.height + barHeight) / 2f),
                strokeWidth = 2.2.dp.toPx(),
                cap = StrokeCap.Round,
            )
        }
    }
}

internal fun CallRecordingUiState.displayDuration(): String {
    message?.let { return it }
    when (playbackState) {
        CallRecordingPlaybackState.Loading -> return "录音加载中"
        CallRecordingPlaybackState.Error -> return "录音加载失败"
        else -> Unit
    }
    val total = durationMillis ?: return when (playbackState) {
        CallRecordingPlaybackState.Playing -> "播放中"
        CallRecordingPlaybackState.Paused -> "已暂停"
        else -> "点击播放"
    }
    val remaining = when (playbackState) {
        CallRecordingPlaybackState.Playing,
        CallRecordingPlaybackState.Paused -> (total - playbackPositionMillis).coerceAtLeast(0L)
        else -> total
    }
    val totalSeconds = (remaining + 999L) / 1_000L
    return "%02d:%02d".format(totalSeconds / 60L, totalSeconds % 60L)
}
