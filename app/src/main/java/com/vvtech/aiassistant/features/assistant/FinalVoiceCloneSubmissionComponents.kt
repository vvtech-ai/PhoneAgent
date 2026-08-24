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
import androidx.compose.ui.res.stringResource
import com.vvtech.aiassistant.R
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

@Composable
private fun submissionContent(state: VoiceCloneSubmissionState, error: String?): SubmissionContent =
    when (state) {
        VoiceCloneSubmissionState.SUBMITTING -> SubmissionContent(
            stringResource(R.string.voice_clone_submitting_title),
            stringResource(R.string.voice_clone_submitting_detail),
            stringResource(R.string.voice_clone_submitting_action)
        )
        VoiceCloneSubmissionState.PROCESSING -> SubmissionContent(
            stringResource(R.string.voice_clone_processing_title),
            stringResource(R.string.voice_clone_processing_detail),
            stringResource(R.string.voice_clone_refresh_status)
        )
        VoiceCloneSubmissionState.FAILED -> SubmissionContent(
            stringResource(R.string.voice_clone_failed_title),
            error?.takeIf(String::isNotBlank) ?: stringResource(R.string.voice_clone_failed_default_detail),
            stringResource(R.string.voice_identity_record_again)
        )
        VoiceCloneSubmissionState.UNKNOWN -> SubmissionContent(
            stringResource(R.string.voice_clone_unknown_title),
            stringResource(R.string.voice_clone_unknown_detail),
            stringResource(R.string.voice_clone_refresh_status)
        )
        else -> SubmissionContent("", "", stringResource(R.string.voice_clone_refresh_status))
    }
