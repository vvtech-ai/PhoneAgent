package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.*

/** Only actual consent presentation. No permission gate, enrollment or SDK. */
@Composable
fun CloneConsentReference(scene: String, onBack: () -> Unit) {
    val state = VoiceCloneEnrollmentState(
        agreementAccepted = scene != "clone-consent",
        busy = scene == "clone-consent-busy"
    )
    PhoneFrameWithBackground {
        Column(Modifier.fillMaxSize()) {
            VoiceCloneFlowTopBar(title = "身份认证", onBack = onBack)
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                    .padding(start = 20.dp, end = 20.dp, bottom = 24.dp)
            ) {
                VoiceCloneConsentStep(VoiceCloneEnrollmentUiArgs(
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
