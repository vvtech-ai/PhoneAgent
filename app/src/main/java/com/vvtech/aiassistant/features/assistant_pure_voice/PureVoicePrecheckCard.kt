package com.vvtech.aiassistant.features.assistant_pure_voice

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun PureVoicePrecheckCard(state: PureVoicePrecheckUiState) {
    val cardColor = Color(0xFFF8FAFD)
    val horizontalPadding = if (state.inline) 14.dp else 18.dp
    val verticalPadding = if (state.inline) 14.dp else 18.dp
    val widthFraction = if (state.inline) 1f else 0.92f
    Surface(
        modifier = Modifier
            .fillMaxWidth(widthFraction)
            .wrapContentWidth(Alignment.CenterHorizontally),
        shape = RoundedCornerShape(16.dp),
        color = cardColor,
        border = BorderStroke(1.dp, if (state.blocking) Color(0xFFFFD7D7) else Color(0xFFE0E7F0))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = horizontalPadding, vertical = verticalPadding),
            verticalArrangement = Arrangement.spacedBy(if (state.inline) 12.dp else 16.dp)
        ) {
            Text(
                text = state.title,
                color = Color(0xFF111827),
                fontSize = if (state.inline) 14.sp else 16.sp,
                fontWeight = FontWeight.SemiBold
            )
            state.items.forEach { item ->
                PureVoicePrecheckRow(item)
            }
            if (state.footer.isNotBlank()) {
                Text(
                    text = state.footer,
                    color = if (state.blocking) Color(0xFFB42318) else Color(0xFF64748B),
                    fontSize = 12.sp,
                    lineHeight = 17.sp
                )
            }
        }
    }
}

@Composable
private fun PureVoicePrecheckRow(item: PureVoicePrecheckItemUiState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .size(10.dp)
                .clip(CircleShape)
                .background(item.dotColor())
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(1.dp)
        ) {
            Text(
                text = item.title,
                color = Color(0xFF111827),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = item.detail,
                color = item.detailColor(),
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
    }
}

private fun PureVoicePrecheckItemUiState.dotColor(): Color =
    when (state) {
        PureVoicePrecheckItemState.Checking -> Color(0xFF8EC5FF)
        PureVoicePrecheckItemState.Passed -> Color(0xFF34C759)
        PureVoicePrecheckItemState.Warning -> Color(0xFF8EC5FF)
        PureVoicePrecheckItemState.Blocked -> Color(0xFFDC2626)
    }

private fun PureVoicePrecheckItemUiState.detailColor(): Color =
    when (state) {
        PureVoicePrecheckItemState.Passed -> Color(0xFF2E7D32)
        PureVoicePrecheckItemState.Blocked -> Color(0xFFB42318)
        PureVoicePrecheckItemState.Checking,
        PureVoicePrecheckItemState.Warning -> Color(0xFF94A3B8)
    }
