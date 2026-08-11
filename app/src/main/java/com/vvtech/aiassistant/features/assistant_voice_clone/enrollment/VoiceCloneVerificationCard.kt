package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.VoiceAccentBlue
import com.vvtech.aiassistant.features.assistant.VoiceCard
import com.vvtech.aiassistant.features.assistant.VoiceTextSecondary

@Composable
internal fun VoiceCloneVerificationCard(
    status: String,
    error: Boolean = false
) {
    VoiceCard(
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFFF8FAFC),
        borderColor = Color(0xFFE5E7EB),
        shadow = false
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            PrototypeFaceFrame()
            if (!error) {
                CircularProgressIndicator(
                    modifier = Modifier.padding(top = 14.dp).size(22.dp),
                    color = VoiceAccentBlue,
                    strokeWidth = 2.dp
                )
            }
            Text(
                text = status,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = if (error) 14.dp else 10.dp),
                color = if (error) Color(0xFFE14D46) else VoiceTextSecondary,
                fontSize = 13.sp,
                lineHeight = 20.sp,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun PrototypeFaceFrame() {
    val frameShape = RoundedCornerShape(
        topStart = 76.dp,
        topEnd = 76.dp,
        bottomStart = 62.dp,
        bottomEnd = 62.dp
    )
    Box(
        modifier = Modifier
            .width(152.dp)
            .height(188.dp)
            .clip(frameShape)
            .background(Brush.verticalGradient(listOf(Color(0xFFEFF6FF), Color.White)))
            .border(2.dp, Color(0xFFBFDBFE), frameShape),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(88.dp)
                .clip(CircleShape)
                .background(Brush.verticalGradient(listOf(Color(0xFF93C5FD), Color(0xFF2563EB))))
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset(y = 13.dp)
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.92f))
            )
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .offset(y = 10.dp)
                    .width(68.dp)
                    .height(43.dp)
                    .clip(RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp))
                    .background(Color.White.copy(alpha = 0.88f))
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth(0.76f)
                .height(2.dp)
                .background(Color(0x8C2563EB))
        )
    }
}
