package com.vvtech.aiassistant.features.assistant

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun BatchCallStatusCard(
    events: List<String>,
    modifier: Modifier = Modifier
) {
    val visibleEvents = events
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .distinct()
        .takeLast(5)
    if (visibleEvents.isEmpty()) return

    val latest = visibleEvents.last()
    val running = !latest.looksLikeTerminalBatchCallStatus()
    val pulse by rememberInfiniteTransition(label = "batchCallStatusPulse").animateFloat(
        initialValue = 0.38f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(animation = tween(780), repeatMode = RepeatMode.Reverse),
        label = "batchCallStatusPulseAlpha"
    )

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = Color.White.copy(alpha = 0.96f),
        border = BorderStroke(1.dp, if (running) Color(0xFFBBD7FF) else Color(0xFFCFEED8)),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(9.dp)
                        .alpha(if (running) pulse else 1f)
                        .clip(CircleShape)
                        .background(if (running) Color(0xFF0A84FF) else Color(0xFF22C55E))
                )
                Text(
                    text = if (running) {
                        currentAppText("通话执行中", "Calls in Progress")
                    } else {
                        currentAppText("通话执行完成", "Calls Complete")
                    },
                    modifier = Modifier.padding(start = 8.dp),
                    color = if (running) Color(0xFF0A84FF) else Color(0xFF15803D),
                    fontSize = 12.sp,
                    lineHeight = 15.sp,
                    fontWeight = FontWeight.ExtraBold
                )
            }

            visibleEvents.takeLast(4).asReversed().forEach { event ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Spacer(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(event.batchCallStatusColor())
                    )
                    Text(
                        text = localizedFinalTaskText(event),
                        modifier = Modifier.padding(start = 8.dp),
                        color = Color(0xFF475467),
                        fontSize = 13.sp,
                        lineHeight = 18.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}

private fun String.looksLikeTerminalBatchCallStatus(): Boolean {
    return contains("任务完成") ||
        contains("任务部分完成") ||
        contains("未完成") ||
        contains("结果未确认") ||
        contains("已取消") ||
        contains("通话已结束") ||
        contains("通话未完成") ||
        contains("批量外呼完成") ||
        // 旧值兼容
        contains("通话完成") ||
        contains("已应邀") ||
        contains("未应邀") ||
        contains("未接电话") ||
        contains("被挂断") ||
        contains("待确认")
}

private fun String.batchCallStatusColor(): Color = when {
    contains("未完成") ||
        // 旧值兼容
        contains("未应邀") || contains("未接电话") || contains("被挂断") || contains("待确认") -> Color(0xFFF97316)
    contains("任务完成") || contains("已应邀") || contains("完成") -> Color(0xFF22C55E)
    else -> Color(0xFF0A84FF)
}
