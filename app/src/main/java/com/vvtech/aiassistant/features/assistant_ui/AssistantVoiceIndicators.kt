package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
internal fun AssistantVoiceWave() {
    val transition = rememberInfiniteTransition(label = "wave")
    val scaleA by transition.animateFloat(
        initialValue = 0.40f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleA"
    )
    val scaleB by transition.animateFloat(
        initialValue = 0.35f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, delayMillis = 70, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleB"
    )
    val scaleC by transition.animateFloat(
        initialValue = 0.45f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, delayMillis = 140, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleC"
    )
    val scaleD by transition.animateFloat(
        initialValue = 0.38f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, delayMillis = 210, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleD"
    )
    val scaleE by transition.animateFloat(
        initialValue = 0.42f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, delayMillis = 280, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleE"
    )
    val scaleF by transition.animateFloat(
        initialValue = 0.34f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, delayMillis = 350, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleF"
    )
    val scaleG by transition.animateFloat(
        initialValue = 0.40f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 560, delayMillis = 420, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "waveScaleG"
    )
    val heights = listOf(10.dp, 14.dp, 18.dp, 12.dp, 18.dp, 14.dp, 10.dp)
    val scales = listOf(scaleA, scaleB, scaleC, scaleD, scaleE, scaleF, scaleG)
    Row(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
        scales.forEachIndexed { index, scale ->
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(heights[index] * scale)
                    .background(Color.White.copy(alpha = 0.92f), RoundedCornerShape(999.dp))
            )
        }
    }
}

@Composable
internal fun AssistantPauseGlyph() {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(16.dp)
                .background(Color.White, RoundedCornerShape(999.dp))
        )
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(16.dp)
                .background(Color.White, RoundedCornerShape(999.dp))
        )
    }
}
