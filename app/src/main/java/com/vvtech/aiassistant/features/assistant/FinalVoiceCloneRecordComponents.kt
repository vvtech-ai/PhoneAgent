package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneFaceUiArgs
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import kotlinx.coroutines.delay

@Composable
internal fun VoiceCloneRecordStep(
    scripts: List<VoiceCloneScriptItem>,
    samples: Map<String, VoiceCloneLocalSample>,
    loading: Boolean,
    uploading: Boolean,
    error: String?,
    recordingScriptId: String?,
    face: VoiceCloneFaceUiArgs,
    currentScriptIndex: Int,
    onRefresh: () -> Unit,
    onRecord: (VoiceCloneScriptItem) -> Unit,
    onStop: (VoiceCloneScriptItem) -> Unit,
    onSubmitRecording: () -> Unit
) {
    val safeIndex = currentScriptIndex.coerceIn(0, (scripts.size - 1).coerceAtLeast(0))
    val script = scripts.getOrNull(safeIndex)
    val sample = script?.let { samples[it.scriptId] }
    val isRecording = script != null && recordingScriptId == script.scriptId
    var elapsedSeconds by remember(script?.scriptId, isRecording) { mutableStateOf(0) }

    LaunchedEffect(script?.scriptId, isRecording) {
        elapsedSeconds = 0
        while (isRecording) {
            delay(1000L)
            elapsedSeconds += 1
        }
    }

    Column {
        VoiceCloneFacePreviewSection(face, isRecording, script?.text)

        if (script == null) {
            Text(
                text = if (loading) "正在加载录音脚本..." else "录音脚本未加载，请刷新后重试。",
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 24.dp),
                color = VoiceTextSecondary,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                textAlign = TextAlign.Center
            )
            VoicePrimaryButton(
                text = if (loading) "刷新中..." else "刷新状态",
                enabled = !loading,
                onClick = onRefresh
            )
        } else VoiceCloneActiveRecordContent(
            script = script,
            sample = sample,
            loading = loading,
            uploading = uploading,
            error = error,
            isRecording = isRecording,
            readyToRecord = face.snapshot.readyToRecord,
            elapsedSeconds = elapsedSeconds,
            onRecord = onRecord,
            onStop = onStop,
            onSubmitRecording = onSubmitRecording
        )
    }
}

@Composable
internal fun VoiceRecordWarning(text: String?, positive: Boolean) {
    if (text.isNullOrBlank()) return
    Surface(
        color = if (positive) Color(0xFFD1FAE5) else Color(0xFFFEF3C7),
        shape = RoundedCornerShape(8.dp),
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
            color = if (positive) Color(0xFF059669) else Color(0xFFD97706),
            fontSize = 13.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
internal fun VoicePrimaryButton(
    text: String,
    enabled: Boolean,
    modifier: Modifier = Modifier.fillMaxWidth(),
    secondary: Boolean = false,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier
            .height(50.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(enabled = enabled, onClick = onClick),
        color = when {
            !enabled -> Color(0xFFE5E7EB)
            secondary -> Color(0xFFE5E7EB)
            else -> VoiceAccentBlue
        },
        shape = RoundedCornerShape(12.dp),
        elevation = 0.dp
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = text,
                color = if (enabled && !secondary) Color.White else Color(0xFF374151),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
internal fun VoiceSmallButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .clickable(enabled = enabled, onClick = onClick),
        color = VoiceAccentBlue,
        shape = RoundedCornerShape(16.dp),
        elevation = 0.dp
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 13.dp, vertical = 10.dp),
            color = Color.White,
            fontSize = 13.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

@Composable
internal fun VoiceCard(
    modifier: Modifier = Modifier,
    selected: Boolean = false,
    color: Color = Color.White.copy(alpha = 0.80f),
    borderColor: Color = Color.White.copy(alpha = 0.78f),
    shadow: Boolean = true,
    contentPadding: PaddingValues = PaddingValues(0.dp),
    content: @Composable () -> Unit
) {
    val shape = RoundedCornerShape(24.dp)
    val shadowModifier = if (shadow) {
        modifier.shadow(
            elevation = if (selected) 18.dp else 10.dp,
            shape = shape,
            ambientColor = if (selected) Color(0x1A0A84FF) else Color(0x14101114),
            spotColor = if (selected) Color(0x1A0A84FF) else Color(0x14101114)
        )
    } else {
        modifier
    }
    Surface(
        modifier = shadowModifier
            .then(
                if (selected) {
                    Modifier.border(BorderStroke(1.5.dp, Color(0x570A84FF)), shape)
                } else {
                    Modifier
                }
            ),
        color = color,
        shape = shape,
        border = BorderStroke(1.dp, borderColor),
        elevation = 0.dp
    ) {
        Box(modifier = Modifier.padding(contentPadding)) {
            content()
        }
    }
}

internal fun recordWarningText(
    error: String?,
    sample: VoiceCloneLocalSample?
): String? {
    if (!error.isNullOrBlank()) return error
    if (sample == null) return null
    return sample.qualityWarnings.firstOrNull()?.takeIf { it.isNotBlank() } ?: "录音完成，可提交"
}

internal fun formatCloneTimer(totalSeconds: Int): String {
    val safeSeconds = totalSeconds.coerceAtLeast(0)
    return "%02d:%02d".format(safeSeconds / 60, safeSeconds % 60)
}
