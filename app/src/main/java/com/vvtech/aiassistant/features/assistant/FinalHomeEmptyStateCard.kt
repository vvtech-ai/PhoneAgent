package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames

@Composable
internal fun FinalHomeEmptyStateCard(
    onOpenTranslationDial: (() -> Unit)? = null,
    callModelTitle: String = AssistantCallModelDisplayNames.Qwen,
    onOpenCallModelSheet: (() -> Unit)? = null,
    sloganTitle: String = "给我一个任务",
    sloganSubtitle: String = "我来帮你打电话"
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 250.dp, max = 320.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 24.dp, end = 24.dp, top = 18.dp, bottom = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier.size(84.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .shadow(
                            elevation = 18.dp,
                            shape = RoundedCornerShape(28.dp),
                            ambientColor = Color(0x1A007AFF),
                            spotColor = Color(0x1A007AFF)
                        )
                        .background(
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    Color.White.copy(alpha = 0.94f),
                                    Color(0xFFF1F5FC).copy(alpha = 0.94f)
                                )
                            ),
                            shape = RoundedCornerShape(28.dp)
                        )
                        .border(
                            BorderStroke(1.dp, Color.White.copy(alpha = 0.92f)),
                            RoundedCornerShape(28.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    FinalHomeVoiceMark(modifier = Modifier.size(60.dp))
                }
            }
            Text(
                text = sloganTitle,
                modifier = Modifier.padding(top = 18.dp),
                color = Color(0xFF121826),
                fontSize = 28.sp,
                lineHeight = 31.sp,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = sloganSubtitle,
                modifier = Modifier
                    .widthIn(max = 292.dp)
                    .padding(top = 12.dp),
                color = Color(0xFF6E6E73),
                fontSize = 14.sp,
                lineHeight = 22.sp,
                textAlign = TextAlign.Center
            )
            if (onOpenCallModelSheet != null) {
                Surface(
                    modifier = Modifier
                        .padding(top = 22.dp)
                        .clickable(onClick = onOpenCallModelSheet),
                    color = Color(0xFF0A84FF),
                    shape = RoundedCornerShape(999.dp),
                    border = null,
                    elevation = 0.dp
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        Text("通话模型：", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Text(v61CallModelDisplayName(callModelTitle), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold)
                        Icon(
                            imageVector = Icons.Rounded.KeyboardArrowDown,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
            if (onOpenTranslationDial != null) {
                Spacer(modifier = Modifier.height(18.dp))
                Surface(
                    modifier = Modifier.clickable { onOpenTranslationDial() },
                    color = Color(0xFF111827),
                    shape = RoundedCornerShape(999.dp)
                ) {
                    Text(
                        text = "实时翻译电话",
                        modifier = Modifier.padding(horizontal = 18.dp, vertical = 10.dp),
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

private fun v61CallModelDisplayName(raw: String): String =
    AssistantCallModelDisplayNames.resolveOrDefault(raw)

@Composable
private fun FinalHomeVoiceMark(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val scale = size.width / 60f
        val barWidth = 4.36f * scale
        val radius = barWidth / 2f
        val brush = Brush.verticalGradient(
            colors = listOf(Color(0xFF7561FC), Color(0xFF1AD5FF)),
            startY = 0f,
            endY = size.height
        )
        val bars = listOf(
            6.51f to 6.14f,
            13.60f to 10.92f,
            20.69f to 27.97f,
            27.78f to 43.00f,
            34.87f to 27.97f,
            41.96f to 10.92f,
            49.05f to 6.14f
        )

        bars.forEach { (xDp, heightDp) ->
            val barHeight = heightDp * scale
            drawRoundRect(
                brush = brush,
                topLeft = Offset(xDp * scale, (size.height - barHeight) / 2f),
                size = Size(barWidth, barHeight),
                cornerRadius = CornerRadius(radius, radius)
            )
        }
    }
}
