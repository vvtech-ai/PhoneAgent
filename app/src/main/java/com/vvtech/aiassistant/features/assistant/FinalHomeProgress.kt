package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun FinalTaskProgressV2(
    modifier: Modifier = Modifier,
    activeStage: Int = 1
) {
    val labels = listOf(
        currentAppText("任务下达", "Task Request"),
        currentAppText("需求确认", "Confirm Details"),
        currentAppText("执行通话", "Start Call"),
        currentAppText("执行结果", "Results")
    )
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 2.dp, bottom = 8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            labels.forEachIndexed { index, label ->
                val stageNumber = index + 1
                val textColor = when {
                    activeStage > stageNumber -> Color(0xFF34C759)
                    activeStage == stageNumber -> Color(0xFF0A84FF)
                    else -> Color(0xFF98A2B3)
                }
                Text(
                    text = label,
                    modifier = Modifier.weight(1f),
                    color = textColor,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            labels.indices.forEach { index ->
                val stageNumber = index + 1
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color(0xFFDCE5F0))
                ) {
                    if (activeStage >= stageNumber) {
                        val fillColors = if (activeStage > stageNumber) {
                            listOf(Color(0xFF30D158), Color(0xFF34C759))
                        } else {
                            listOf(Color(0xFF0A84FF), Color(0xFF49A4FF))
                        }
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Brush.horizontalGradient(fillColors))
                        )
                    }
                }
            }
        }
    }
}
