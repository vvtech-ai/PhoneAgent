package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val DotColor = Color(0xFF6B5FCC)

@Composable
fun StreamingThinkingDots(
    label: String = "thinking",
    modifier: Modifier = Modifier
) {
    val transition = rememberInfiniteTransition(label = "thinking-dots")
    val alphas = listOf(
        transition.animateFloat(
            0.25f, 1f,
            infiniteRepeatable(tween(600), RepeatMode.Reverse),
            label = "dot-1"
        ),
        transition.animateFloat(
            0.25f, 1f,
            infiniteRepeatable(tween(600, delayMillis = 150), RepeatMode.Reverse),
            label = "dot-2"
        ),
        transition.animateFloat(
            0.25f, 1f,
            infiniteRepeatable(tween(600, delayMillis = 300), RepeatMode.Reverse),
            label = "dot-3"
        )
    )
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier.padding(vertical = 2.dp)
    ) {
        Text(
            text = label,
            color = DotColor,
            fontSize = 13.sp
        )
        Spacer(modifier = Modifier.width(6.dp))
        alphas.forEachIndexed { idx, anim ->
            if (idx > 0) Spacer(modifier = Modifier.width(3.dp))
            androidx.compose.foundation.layout.Box(
                modifier = Modifier
                    .size(5.dp)
                    .alpha(anim.value)
                    .clip(CircleShape)
                    .background(DotColor)
            )
        }
    }
}
