package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneCameraPreview
import com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneFaceUiArgs
import com.vvtech.aiassistant.model.VoiceCloneScriptItem

@Composable
internal fun VoiceCloneFacePreviewSection(
    face: VoiceCloneFaceUiArgs,
    isRecording: Boolean,
    scriptText: String?
) {
    Text(
        text = currentAppText(
            "请保持面部位于取景框中央。",
            "Keep your face centered in the frame."
        ),
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
        color = Color(0xFFB0B4C3),
        fontSize = 12.sp,
        lineHeight = 17.sp,
        textAlign = TextAlign.Center
    )
    VoiceCard(
        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
        color = Color(0xFFF8FAFC),
        borderColor = Color(0xFFE5E7EB),
        shadow = false
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
            VoiceCloneCameraPreview(
                callbacks = face.callbacks,
                modifier = Modifier.clip(RoundedCornerShape(18.dp))
            )
            Text(
                text = facePresenceLabel(face),
                modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
                color = if (face.snapshot.readyToRecord || isRecording) {
                    Color(0xFF059669)
                } else {
                    Color(0xFFD97706)
                },
                fontSize = 12.sp,
                lineHeight = 18.sp,
                textAlign = TextAlign.Center
            )
            if (!scriptText.isNullOrBlank()) {
                Text(
                    text = currentAppText(
                        "请朗读以下内容：\n$scriptText",
                        "Please read the following:\n$scriptText"
                    ),
                    modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
                    color = Color(0xFF4B5563),
                    fontSize = 13.sp,
                    lineHeight = 21.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
        horizontalArrangement = Arrangement.Center
    ) {
        VoiceDeviceChip(
            text = if (face.snapshot.cameraReady) {
                currentAppText("摄像头已开启", "Camera On")
            } else {
                currentAppText("正在准备摄像头", "Preparing Camera")
            },
            active = face.snapshot.cameraReady
        )
        VoiceDeviceChip(
            text = if (isRecording) {
                currentAppText("麦克风采集中", "Microphone Recording")
            } else {
                currentAppText("麦克风已就绪", "Microphone Ready")
            },
            active = isRecording,
            modifier = Modifier.padding(start = 8.dp)
        )
    }
}

@Composable
private fun VoiceDeviceChip(
    text: String,
    active: Boolean,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = Color(0xFFEEF6FF),
        shape = RoundedCornerShape(50),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(if (active) Color(0xFF22C55E) else Color(0xFFF59E0B))
            )
            Text(
                text = text,
                color = Color(0xFF2563EB),
                fontSize = 12.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
internal fun VoiceCloneActiveRecordContent(
    script: VoiceCloneScriptItem,
    sample: VoiceCloneLocalSample?,
    loading: Boolean,
    uploading: Boolean,
    error: String?,
    isRecording: Boolean,
    readyToRecord: Boolean,
    elapsedSeconds: Int,
    onRecord: (VoiceCloneScriptItem) -> Unit,
    onStop: (VoiceCloneScriptItem) -> Unit,
    onSubmitRecording: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier.size(72.dp).clip(CircleShape)
                .background(if (isRecording) Color(0xFFEF4444) else VoicePrimaryBlue)
                .clickable(
                    enabled = !uploading && (isRecording || readyToRecord),
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() }
                ) { if (isRecording) onStop(script) else onRecord(script) },
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Outlined.Mic, null, Modifier.size(28.dp), Color.White)
        }
        if (isRecording) {
            Text(
                formatCloneTimer(elapsedSeconds),
                color = VoiceTextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold
            )
        }
        Text(
            when {
                isRecording -> currentAppText("点击按钮结束录音", "Tap the button to stop recording")
                sample != null -> currentAppText("录音已完成", "Recording complete")
                else -> currentAppText("点击按钮开始录音", "Tap the button to start recording")
            },
            color = VoiceTextMuted,
            fontSize = 13.sp
        )
        VoiceRecordWarning(
            text = recordWarningText(error, sample),
            positive = error.isNullOrBlank() && sample != null && !sample.qualityBlocked
        )
    }
    VoicePrimaryButton(
        text = if (uploading) currentAppText("提交中...", "Submitting...") else currentAppText("提交录音", "Submit Recording"),
        enabled = !loading && !uploading && !isRecording && sample != null && !sample.qualityBlocked,
        onClick = onSubmitRecording
    )
}

private fun facePresenceLabel(face: VoiceCloneFaceUiArgs): String = when {
    !face.snapshot.cameraReady -> currentAppText("正在准备前置摄像头", "Preparing front camera")
    face.snapshot.currentFaceCount == 1 -> currentAppText("已检测到单人脸，请保持正对镜头", "Single face detected. Keep facing the camera")
    face.snapshot.currentFaceCount > 1 -> currentAppText("请确保镜头中只有一人", "Make sure only one person is in frame")
    else -> currentAppText("请将面部完整置于镜头中", "Place your full face inside the frame")
}
