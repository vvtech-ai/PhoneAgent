package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
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
import com.vvtech.aiassistant.features.assistant.VoiceAccentBlue
import com.vvtech.aiassistant.features.assistant.VoiceTextPrimary

private const val COMPLETION_DESCRIPTION = "声音克隆已完成，可用于 Agent 通话。"

@Composable
internal fun VoiceCloneDoneStep(
    actionLoading: Boolean,
    onStartUsing: (Boolean) -> Unit
) {
    Column(
        modifier = Modifier.padding(horizontal = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        CompletionIcon()
        Text(
            text = "完成声音克隆",
            color = VoiceTextPrimary,
            fontSize = 22.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        CompletionDescription()
        CompletionPrimaryButton(
            text = if (actionLoading) "处理中..." else "开始使用",
            enabled = !actionLoading,
            onClick = { onStartUsing(false) }
        )
        Text(
            text = "你随时可以在 设置 > 语音 中管理声音数据",
            modifier = Modifier.padding(top = 12.dp),
            color = Color(0xFFB0B4C3),
            fontSize = 12.sp,
            lineHeight = 17.sp,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun CompletionIcon() {
    Box(
        modifier = Modifier
            .padding(top = 20.dp, bottom = 16.dp)
            .size(80.dp)
            .clip(CircleShape)
            .background(Color(0xFFD1FAE5)),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Rounded.Check,
            contentDescription = "完成",
            tint = Color(0xFF059669),
            modifier = Modifier.size(40.dp)
        )
    }
}

@Composable
private fun CompletionDescription() {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 24.dp),
        color = Color(0xFFF0FDF4),
        shape = RoundedCornerShape(20.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFD1FAE5)),
        elevation = 0.dp
    ) {
        Text(
            text = COMPLETION_DESCRIPTION,
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            color = Color(0xFF374151),
            fontSize = 14.sp,
            lineHeight = 20.sp,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun CompletionPrimaryButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(enabled = enabled, onClick = onClick),
        color = VoiceAccentBlue.copy(alpha = if (enabled) 1f else 0.45f),
        shape = RoundedCornerShape(12.dp),
        elevation = 0.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = text,
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
        }
    }
}
