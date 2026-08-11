package com.vvtech.aiassistant.features.assistant

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun FinalNormalCallPageV3(
    phoneNumber: String,
    seconds: Int,
    muted: Boolean,
    speakerEnabled: Boolean,
    onBack: () -> Unit,
    onMuteToggle: () -> Unit,
    onSpeakerToggle: () -> Unit,
    onHangup: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        FinalFlowTopBar(backLabel = "返回", onBack = onBack)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .background(
                        brush = Brush.verticalGradient(listOf(Color(0xFF7AA8FF), Color(0xFF4F7DFF))),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = phoneNumber.trim().take(1).ifBlank { "#" },
                    color = Color.White,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.ExtraBold
                )
            }
            Text(
                text = if (phoneNumber.isBlank()) "未知号码" else phoneNumber,
                modifier = Modifier.padding(top = 18.dp),
                color = Color(0xFF111111),
                fontSize = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.sp
            )
            Text(
                text = formatSeconds(seconds),
                modifier = Modifier.padding(top = 10.dp),
                color = Color(0xFF6E6E73),
                fontSize = 15.sp
            )
            Surface(
                modifier = Modifier.padding(top = 12.dp),
                color = Color(0x1F34C759),
                shape = RoundedCornerShape(999.dp),
                elevation = 0.dp
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(Color(0xFF34C759), CircleShape)
                    )
                    Text(
                        text = "普通通话 · 已接通",
                        color = Color(0xFF34C759),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 28.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                FinalCallControlV3(
                    label = if (muted) "取消静音" else "静音",
                    icon = "🎙",
                    modifier = Modifier.weight(1f),
                    onClick = onMuteToggle
                )
                FinalCallControlV3(
                    label = "键盘",
                    icon = "⌗",
                    modifier = Modifier.weight(1f),
                    onClick = {}
                )
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                FinalCallControlV3(
                    label = if (speakerEnabled) "关闭外放" else "开启外放",
                    icon = "🔊",
                    modifier = Modifier.weight(1f),
                    onClick = onSpeakerToggle
                )
                FinalCallControlV3(
                    label = "添加通话",
                    icon = "+",
                    modifier = Modifier.weight(1f),
                    onClick = {}
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            FinalActionButton(
                label = "结束通话",
                tone = FinalButtonTone.Danger,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 6.dp),
                onClick = onHangup
            )
        }
    }
}

@Composable
internal fun FinalCallControlV3(
    label: String,
    icon: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        color = Color.White.copy(alpha = 0.84f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.82f)),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = icon, fontSize = 22.sp)
            Text(
                text = label,
                modifier = Modifier.padding(top = 8.dp),
                color = Color(0xFF111111),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
