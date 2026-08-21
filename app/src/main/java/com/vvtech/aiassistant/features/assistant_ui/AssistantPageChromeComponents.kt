package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun AssistantScreenTopBar(
    title: String,
    subtitle: String = "",
    trailing: (@Composable () -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp, bottom = 10.dp, start = 18.dp, end = 18.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = Color(0xFF111111),
                fontSize = 31.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp,
                maxLines = 1
            )
            if (subtitle.isNotBlank()) {
                Text(
                    text = subtitle,
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
        }
        Box(modifier = Modifier.padding(start = 10.dp)) {
            if (trailing != null) {
                trailing()
            } else {
                Spacer(modifier = Modifier.size(40.dp))
            }
        }
    }
}

@Composable
@Suppress("UNUSED_PARAMETER")
internal fun AssistantFlowTopBar(
    backLabel: String,
    onBack: () -> Unit,
    onStop: (() -> Unit)? = null
) {
    AssistantBackIconBar(onBack = onBack, onStop = onStop)
}

@Composable
internal fun AssistantBackTitleBar(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    dark: Boolean = false,
    trailing: (@Composable () -> Unit)? = null
) {
    val contentColor = if (dark) Color.White else Color(0xFF111111)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 8.dp, start = 18.dp, end = 18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "‹",
            modifier = Modifier
                .width(28.dp)
                .offset(y = (-2).dp)
                .clickable(onClick = onBack),
            textAlign = TextAlign.Center,
            color = contentColor,
            fontSize = 30.sp,
            lineHeight = 30.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            color = contentColor,
            fontSize = 26.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 0.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
        if (trailing != null) {
            trailing()
        } else {
            Spacer(modifier = Modifier.size(40.dp))
        }
    }
}

@Composable
internal fun AssistantBackIconBar(
    onBack: () -> Unit,
    onStop: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 8.dp, start = 18.dp, end = 18.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "‹",
            modifier = Modifier
                .width(28.dp)
                .offset(y = (-2).dp)
                .clickable(onClick = onBack),
            textAlign = TextAlign.Center,
            color = Color(0xFF111111),
            fontSize = 30.sp,
            lineHeight = 30.sp,
            fontWeight = FontWeight.Bold
        )
        if (onStop != null) {
            AssistantStopButton(onClick = onStop)
        } else {
            Spacer(modifier = Modifier.size(40.dp))
        }
    }
}

@Composable
internal fun AssistantStopButton(onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .size(30.dp)
            .clickable(onClick = onClick),
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
}

@Composable
internal fun AssistantFlowTitle(text: String) {
    Text(
        text = text,
        modifier = Modifier.padding(horizontal = 18.dp, vertical = 2.dp),
        color = Color(0xFF111111),
        fontSize = 28.sp,
        lineHeight = 30.sp,
        fontWeight = FontWeight.ExtraBold,
        letterSpacing = 0.sp
    )
}

@Composable
internal fun AssistantAiLoadingBubble(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "clarifyLoading")
    val alpha by transition.animateFloat(
        initialValue = 0.35f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 620, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "clarifyLoadingAlpha"
    )
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        Surface(
            color = Color.White.copy(alpha = 0.84f),
            shape = RoundedCornerShape(18.dp),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.84f)),
            elevation = 0.dp
        ) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 14.dp)
                    .alpha(alpha),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(3) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(Color(0xFF0A84FF), CircleShape)
                    )
                }
            }
        }
    }
}

@Composable
internal fun AssistantMetricCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = label,
                color = Color(0xFF6E6E73),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = value,
                modifier = Modifier.padding(top = 7.dp),
                color = Color(0xFF111111),
                fontSize = 15.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
