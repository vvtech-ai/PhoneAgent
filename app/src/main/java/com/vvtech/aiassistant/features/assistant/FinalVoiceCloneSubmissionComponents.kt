package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState

@Composable
internal fun VoiceCloneSubmissionStep(
    state: VoiceCloneSubmissionState,
    error: String?,
    onRefresh: () -> Unit,
    onRerecord: () -> Unit
) {
    val content = submissionContent(state, error)
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Spacer(Modifier.height(28.dp))
        Text(content.title, color = VoiceTextPrimary, fontSize = 21.sp, fontWeight = FontWeight.Bold)
        Text(
            content.detail,
            color = if (state == VoiceCloneSubmissionState.FAILED) Color(0xFFE14D46) else VoiceTextSecondary,
            fontSize = 13.sp,
            lineHeight = 20.sp,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        VoicePrimaryButton(
            text = content.actionLabel,
            enabled = state != VoiceCloneSubmissionState.SUBMITTING,
            onClick = if (state == VoiceCloneSubmissionState.FAILED) onRerecord else onRefresh
        )
    }
}

private data class SubmissionContent(
    val title: String,
    val detail: String,
    val actionLabel: String
)

private fun submissionContent(state: VoiceCloneSubmissionState, error: String?): SubmissionContent =
    when (state) {
        VoiceCloneSubmissionState.SUBMITTING -> SubmissionContent(
            "正在提交录音",
            "请保持当前页面，服务端正在校验人脸摘要、音频质量和朗读内容。",
            "提交中…"
        )
        VoiceCloneSubmissionState.PROCESSING -> SubmissionContent(
            "正在生成声音",
            "录音已通过校验，声音供应商正在处理。此状态不代表声音克隆已完成。",
            "刷新状态"
        )
        VoiceCloneSubmissionState.FAILED -> SubmissionContent(
            "本次采集未通过",
            error?.takeIf(String::isNotBlank) ?: "本次录音未通过校验，请使用新短句重新录制。",
            "重新录制"
        )
        VoiceCloneSubmissionState.UNKNOWN -> SubmissionContent(
            "提交结果确认中",
            "服务端无法确认供应商结果，已禁止重复提交。请稍后刷新，不会显示为完成。",
            "刷新状态"
        )
        else -> SubmissionContent("", "", "刷新状态")
    }
