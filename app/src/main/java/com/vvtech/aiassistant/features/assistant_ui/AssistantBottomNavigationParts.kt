package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.features.assistant.FinalFadeEase

@Composable
internal fun BoxScope.CenterActionButton(
    centerDialMode: Boolean,
    centerFabHopOffsetDp: Float,
    centerFabHopScale: Float,
    onClick: () -> Unit
) {
    val density = LocalDensity.current
    Surface(
        modifier = Modifier
            .size(60.dp)
            .align(Alignment.TopCenter)
            .offset(y = (-18).dp)
            .graphicsLayer {
                translationY = with(density) { centerFabHopOffsetDp.dp.toPx() }
                scaleX = centerFabHopScale
                scaleY = centerFabHopScale
            }
            .shadow(
                elevation = if (centerDialMode) 14.dp else 18.dp,
                shape = CircleShape,
                ambientColor = if (centerDialMode) Color(0x4D0A84FF) else Color(0x47007AFF),
                spotColor = if (centerDialMode) Color(0x4D0A84FF) else Color(0x47007AFF)
            )
            .clickable(onClick = onClick),
        color = Color.Transparent,
        shape = CircleShape,
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color(0xFF0A84FF),
                            if (centerDialMode) Color(0xFF006FE8) else Color(0xFF0071EB)
                        )
                    ),
                    CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            if (centerDialMode) {
                AssistantDialGlyph()
            } else {
                AssistantVoiceGlyph()
            }
        }
    }
}

@Composable
private fun AssistantVoiceGlyph() {
    Icon(
        painter = painterResource(id = R.drawable.ic_assistant_fab_voice),
        contentDescription = null,
        tint = Color.White,
        modifier = Modifier.size(37.dp)
    )
}

@Composable
private fun AssistantDialGlyph() {
    Box(
        modifier = Modifier
            .size(18.dp)
            .drawBehind {
                val radius = 2.dp.toPx()
                val centers = listOf(2.dp.toPx(), 9.dp.toPx(), 16.dp.toPx())
                centers.forEach { x ->
                    centers.forEach { y ->
                        drawCircle(color = Color.White, radius = radius, center = Offset(x, y))
                    }
                }
            }
    )
}

@Composable
internal fun BottomNavigationItem(
    modifier: Modifier = Modifier,
    iconResId: Int,
    label: String,
    active: Boolean,
    badgeCount: Int = 0,
    onClick: () -> Unit
) {
    val iconTint by animateColorAsState(
        targetValue = if (active) Color(0xFF007AFF) else Color(0xFF6E6E73),
        animationSpec = tween(durationMillis = 180, easing = FinalFadeEase),
        label = "navItemTint"
    )
    Box(modifier = modifier.clickable(onClick = onClick).height(56.dp)) {
        Column(
            modifier = Modifier.align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                painter = painterResource(id = iconResId),
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = label,
                modifier = Modifier.padding(top = 5.dp),
                color = iconTint,
                fontSize = 10.sp,
                fontWeight = FontWeight.ExtraBold
            )
        }
        if (badgeCount > 0) {
            Surface(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-8).dp, y = 2.dp)
                    .height(16.dp)
                    .widthIn(min = 16.dp),
                color = Color(0xFFEF4444),
                shape = RoundedCornerShape(8.dp),
                elevation = 0.dp
            ) {
                Box(
                    modifier = Modifier.padding(horizontal = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = badgeCount.coerceAtMost(99).toString(),
                        color = Color.White,
                        fontSize = 10.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }
        }
    }
}
