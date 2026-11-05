package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.*

/** Actual processing presentation; registered permission gate is never invoked. */
@Composable
fun CloneProcessingReference(scene: String, onBack: () -> Unit) {
    val generating = scene == "clone-generating"
    val state = VoiceCloneEnrollmentState(
        step = if (generating) VoiceCloneEnrollmentStep.CLONING else VoiceCloneEnrollmentStep.VERIFYING,
        verificationPhase = if (scene == "clone-collecting") VoiceCloneVerificationPhase.SDK_COLLECTING else VoiceCloneVerificationPhase.RESULT_CHECKING,
        scriptText = "合成演练，请在七点通知会议。",
        errorMessage = if (scene == "clone-processing-error") "合成认证结果暂未确认" else null
    )
    PhoneFrameWithBackground {
        Column(Modifier.fillMaxSize()) {
            VoiceCloneFlowTopBar(title = if (generating) "3/3 声音克隆" else "2/3 人脸与声音", onBack = onBack)
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
