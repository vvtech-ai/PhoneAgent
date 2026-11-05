package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.*

/** Actual identity presentation; registered permission gate is never invoked. */
@Composable
fun CloneIdentityReference(scene: String, onBack: () -> Unit) {
    val state = VoiceCloneEnrollmentState(
        step = VoiceCloneEnrollmentStep.IDENTITY,
        realName = if (scene == "clone-identity-verified") "演练用户" else "",
        verifiedIdentityLocked = scene == "clone-identity-verified",
        errorMessage = if (scene == "clone-identity-error") "合成填写失败" else null
    )
    PhoneFrameWithBackground {
        Column(Modifier.fillMaxSize()) {
            VoiceCloneFlowTopBar(title = "1/3 填写信息", onBack = onBack)
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                    .padding(start = 20.dp, top = 12.dp, end = 20.dp, bottom = 24.dp)
            ) {
                VoiceCloneEnrollmentContent(VoiceCloneEnrollmentUiArgs(
                    state = state,
                    onAgreementChange = {}, onContinueConsent = {},
                    onIdentityChange = { _, _ -> }, onIdentityEditStarted = {},
                    onPrepareVerification = {}, onConfirmReplacement = {},
                    onDismissReplacement = {}, onStartVerification = {},
                    onVerificationPermissionDenied = {}
                ))
            }
        }
    }
}
