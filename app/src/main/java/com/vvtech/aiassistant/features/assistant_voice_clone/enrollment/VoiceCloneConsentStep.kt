package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
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
import com.vvtech.aiassistant.features.assistant.VoiceCard
import com.vvtech.aiassistant.features.assistant.VoiceTextPrimary
import com.vvtech.aiassistant.features.assistant.VoiceTextSecondary
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal const val VOICE_CLONE_AUTH_DESCRIPTION =
    "只有完成身份认证的用户，才能使用声音克隆服务。"
internal const val VOICE_CLONE_AFTER_AUTH_DESCRIPTION =
    "完成身份认证后，进入声音克隆并生成你的声音。"
internal const val VOICE_CLONE_UNAUTHORIZED_DESCRIPTION =
    "未经授权，AI 不应使用你的声音进行通话。"
internal const val VOICE_CLONE_FOLLOW_UP_DESCRIPTION =
    "后续通话完善声音需单独开启授权。"
internal const val VOICE_CLONE_CONSENT_DESCRIPTION =
    "我确认由本人申请使用本人声音，并同意进行身份认证"

internal fun voiceCloneAuthDescription(): String =
    currentAppText(VOICE_CLONE_AUTH_DESCRIPTION, "Verify your identity to continue.")

internal fun voiceCloneAfterAuthDescription(): String =
    currentAppText(VOICE_CLONE_AFTER_AUTH_DESCRIPTION, "Next, record your voice.")

internal fun voiceCloneUnauthorizedDescription(): String =
    currentAppText(VOICE_CLONE_UNAUTHORIZED_DESCRIPTION, "AI should not use your voice for calls without authorization.")

internal fun voiceCloneFollowUpDescription(): String =
    currentAppText(VOICE_CLONE_FOLLOW_UP_DESCRIPTION, "Separate authorization is required to improve the voice in later calls.")

internal fun voiceCloneConsentDescription(): String =
    currentAppText(VOICE_CLONE_CONSENT_DESCRIPTION, "I confirm that I am applying to use my own voice and agree to identity verification.")

@Composable
internal fun VoiceCloneConsentStep(args: VoiceCloneEnrollmentUiArgs) {
    val state = args.state
    Column(
        modifier = Modifier.padding(horizontal = 10.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        VoiceCard(
            modifier = Modifier.fillMaxWidth(),
            color = Color(0xFFF0F4FF),
            borderColor = Color(0xFFDBEAFE),
            shadow = false
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = currentAppText("身份认证", "Identity Verification"),
                    color = VoiceTextPrimary,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = voiceCloneAuthDescription(),
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    color = VoiceTextSecondary,
                    fontSize = 13.sp,
                    lineHeight = 20.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
        Column {
            ConsentInfoLine(voiceCloneAfterAuthDescription())
            ConsentInfoLine(voiceCloneUnauthorizedDescription())
            ConsentInfoLine(voiceCloneFollowUpDescription())
        }
        VoiceCloneAgreementRow(
            text = voiceCloneConsentDescription(),
            checked = state.agreementAccepted,
            enabled = !state.busy,
            modifier = Modifier.fillMaxWidth(),
            onCheckedChange = args.onAgreementChange
        )
        ConsentError(state.errorMessage)
        ConsentPrimaryButton(
            text = if (state.busy) {
                currentAppText("正在进入认证…", "Starting verification...")
            } else {
                currentAppText("开始认证", "Start Verification")
            },
            enabled = state.agreementAccepted && !state.busy,
            onClick = args.onContinueConsent
        )
    }
}

@Composable
private fun ConsentInfoLine(text: String) {
    Text(
        text = text,
        color = VoiceTextSecondary,
        fontSize = 13.sp,
        lineHeight = 23.sp
    )
}

@Composable
private fun ConsentPrimaryButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
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

@Composable
private fun ConsentError(message: String?) {
    if (!message.isNullOrBlank()) {
        Text(
            text = message,
            color = Color(0xFFE14D46),
            fontSize = 13.sp,
            lineHeight = 18.sp
        )
    }
}
