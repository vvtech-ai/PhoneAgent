package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Checkbox
import androidx.compose.material.CheckboxDefaults
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.rounded.Check
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
@Composable
internal fun VoiceTopBar(
    backLabel: String,
    title: String,
    onBack: () -> Unit,
    onClose: (() -> Unit)? = null
) {
    FinalBackTitleBar(
        title = title,
        onBack = onBack,
        trailing = onClose?.let { close ->
            {
                Text(
                    text = "×",
                    modifier = Modifier
                        .size(40.dp)
                        .clickable(onClick = close)
                        .padding(top = 4.dp),
                    color = VoiceTextMuted,
                    fontSize = 24.sp,
                    lineHeight = 28.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
    )
}
@Composable
internal fun VoiceChoiceCard(
    title: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit
) {
    VoiceCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .clickable(enabled = enabled, onClick = onClick),
        selected = selected
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                color = Color(0xFF111111),
                fontSize = 16.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Bold
            )
            VoiceCheckMark(visible = selected)
        }
    }
}

@Composable
internal fun VoiceCloneGroupCard(
    selected: Boolean,
    status: String,
    detail: String,
    actionLabel: String,
    enabled: Boolean,
    showAction: Boolean,
    onSelect: () -> Unit,
    onAction: () -> Unit
) {
    VoiceCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp),
        selected = selected,
        contentPadding = PaddingValues(0.dp)
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = enabled, onClick = onSelect)
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "我的克隆音色",
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                if (status.isNotBlank()) {
                    Text(
                        text = status,
                        color = Color(0xFF6E6E73),
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, bottom = 16.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (status == "未克隆") Color(0x148E8E93) else Color(0x0F0A84FF))
                    .padding(horizontal = 13.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = detail,
                    modifier = Modifier.weight(1f),
                    color = Color(0xFF6E6E73),
                    fontSize = 12.sp,
                    lineHeight = 17.sp
                )
                if (showAction) {
                    VoiceSmallButton(
                        text = actionLabel,
                        enabled = enabled,
                        onClick = onAction
                    )
                }
            }
        }
    }
}

@Composable
internal fun VoiceCheckMark(visible: Boolean) {
    if (visible) {
        Surface(
            color = Color(0x1A007AFF),
            shape = RoundedCornerShape(999.dp),
            elevation = 0.dp
        ) {
            Text(
                text = "当前使用",
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                color = Color(0xFF0A84FF),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
