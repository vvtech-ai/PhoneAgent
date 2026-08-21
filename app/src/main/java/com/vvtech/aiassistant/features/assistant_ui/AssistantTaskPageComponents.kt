package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalTaskDisplayItem
import com.vvtech.aiassistant.features.assistant.FinalTaskStatusKind
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.delay

@Composable
internal fun AssistantTaskSyncStatusRow(
    title: String,
    detail: String,
    error: Boolean,
    onClick: (() -> Unit)?
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        color = if (error) Color(0xFFFFF1F2) else Color(0xFFEFF6FF),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, if (error) Color(0xFFFECACA) else Color(0xFFBFDBFE)),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
            Text(
                text = title,
                color = if (error) Color(0xFFB91C1C) else Color(0xFF1D4ED8),
                fontSize = 13.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = detail,
                modifier = Modifier.padding(top = 2.dp),
                color = if (error) Color(0xFF991B1B) else Color(0xFF2563EB),
                fontSize = 12.sp,
                lineHeight = 17.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
internal fun AssistantTaskInitialLoading() {
    var dotCount by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(420L)
            dotCount = (dotCount + 1) % 4
        }
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 72.dp, bottom = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Syncing tasks",
                color = Color(0xFF667085),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = ".".repeat(dotCount),
                modifier = Modifier.width(18.dp),
                color = Color(0xFF667085),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
internal fun AssistantTasksTopBar() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 22.dp, end = 22.dp, top = 8.dp, bottom = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Tasks",
                color = Color(0xFF111111),
                fontSize = 31.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp,
                maxLines = 1
            )
        }
    }
}

@Composable
internal fun AssistantTaskDesignRow(
    item: FinalTaskDisplayItem,
    onClick: () -> Unit
) {
    val detailLine = item.secondaryLine
        .takeIf { it.isNotBlank() }
        ?: currentAppText("任务信息已同步", "Task information synced")
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = Color(0x14101114),
                spotColor = Color(0x14101114)
            )
            .clickable(onClick = onClick),
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.displayTitle,
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = detailLine,
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp,
                    lineHeight = 19.sp,
                    letterSpacing = 0.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = item.statusLabel,
                color = assistantTaskStatusColor(item.statusKind),
                fontSize = 12.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp,
                maxLines = 1
            )
        }
    }
}

private fun assistantTaskStatusColor(statusKind: FinalTaskStatusKind): Color = when (statusKind) {
    FinalTaskStatusKind.Completed -> Color(0xFF1F8F46)
    FinalTaskStatusKind.Incomplete -> Color(0xFFFF9F0A)
    FinalTaskStatusKind.Running -> Color(0xFF3B82F6)
    FinalTaskStatusKind.ExecutionError -> Color(0xFFDC2626)
}
