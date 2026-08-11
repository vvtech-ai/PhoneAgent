package com.vvtech.aiassistant.features.assistant_tasks

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.parseInlineMarkdown

@Composable
internal fun AssistantClarifyFallbackBannerCard(
    title: String,
    subtitle: String,
    selected: Boolean,
    required: Boolean,
    onToggleSelected: () -> Unit,
    onToggleRequired: (Boolean) -> Unit
) {
    val stateLabel = when {
        !selected -> "不提及"
        required -> "必须满足"
        else -> "提及但不必须"
    }
    val stateTextColor = when {
        !selected -> Color(0xFF8A93A3)
        required -> Color(0xFF0A84FF)
        else -> Color(0xFF5B6D8D)
    }
    val stateBgColor = when {
        !selected -> Color(0xFFE8ECF2)
        required -> Color(0xFFDDEBFF)
        else -> Color(0xFFEEF2F8)
    }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
            .clickable(onClick = onToggleSelected),
        color = if (selected) Color.White.copy(alpha = 0.90f) else Color(0xFFF0F2F5),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, if (selected) Color(0x4F007AFF) else Color(0xFFE1E6EE)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    color = if (selected) Color(0xFF111111) else Color(0xFF707887),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold
                )
                Surface(
                    color = stateBgColor,
                    shape = RoundedCornerShape(999.dp),
                    elevation = 0.dp
                ) {
                    Text(
                        text = stateLabel,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                        color = stateTextColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = subtitle,
                    modifier = Modifier.weight(1f),
                    color = if (selected) Color(0xFF6E6E73) else Color(0xFF9AA3B2),
                    fontSize = 12.sp,
                    lineHeight = 18.sp
                )
                Spacer(modifier = Modifier.width(10.dp))
                AssistantClarifyFallbackRequiredSwitch(
                    checked = required,
                    enabled = selected,
                    onCheckedChange = onToggleRequired
                )
            }
        }
    }
}

@Composable
private fun AssistantClarifyFallbackRequiredSwitch(
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    val trackColor = when {
        !enabled -> Color(0xFFD9DEE6)
        checked -> Color(0xFF0A84FF)
        else -> Color(0xFFC9D3E2)
    }
    val thumbAlignment = if (enabled && checked) Alignment.CenterEnd else Alignment.CenterStart

    Surface(
        modifier = Modifier
            .width(44.dp)
            .height(24.dp)
            .clickable(enabled = enabled) { onCheckedChange(!checked) },
        color = trackColor,
        shape = RoundedCornerShape(999.dp),
        elevation = 0.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(2.dp),
            contentAlignment = thumbAlignment
        ) {
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .background(Color.White, CircleShape)
            )
        }
    }
}

@Composable
internal fun AssistantClarifyOptionPickerCard(
    title: String,
    subtitle: String,
    tag: String?,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
            .clickable(onClick = onClick),
        color = if (selected) Color(0xFFF6FAFF) else Color.White.copy(alpha = 0.84f),
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, if (selected) Color(0x55007AFF) else Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    text = parseInlineMarkdown(title),
                    color = Color(0xFF111111),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium
                )
                if (tag != null) {
                    Surface(
                        color = Color(0x1A007AFF),
                        shape = RoundedCornerShape(12.dp),
                        elevation = 0.dp
                    ) {
                        Text(
                            text = tag,
                            modifier = Modifier.padding(horizontal = 9.dp, vertical = 6.dp),
                            color = Color(0xFF0A84FF),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                }
            }
            Text(
                text = parseInlineMarkdown(subtitle),
                modifier = Modifier.padding(top = 6.dp),
                color = Color(0xFF6E6E73),
                fontSize = 12.sp,
                lineHeight = 18.sp
            )
        }
    }
}
