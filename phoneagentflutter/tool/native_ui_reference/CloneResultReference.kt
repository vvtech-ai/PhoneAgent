package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_voice_clone.model.*

/** Effective result component; all service, audio and billing callbacks are empty. */
@Composable
fun CloneResultReference(scene: String, onBack: () -> Unit) {
    val state = VoiceCloneModelFlowState(
        phase = VoiceCloneModelFlowPhase.CANDIDATE,
        candidate = VoiceCloneCandidateUi(
            candidateId = "synthetic", modelId = "synthetic", status = "READY",
            source = "VERIFICATION", displayName = "合成音色", lastError = "",
            billingStatus = "CHARGED", chargedPoints = 300, remainingPoints = 900
        ),
        showSaveRecordingOption = true, saveRecording = true,
        actionLoading = scene == "clone-result-busy",
        previewPlaying = scene == "clone-result-playing",
        error = if (scene == "clone-result-error") "合成试听失败，请稍后重试" else null
    )
    VoiceCloneResultPage(state, VoiceCloneModelFlowCallbacks(
        onClose = onBack, onSelectModel = {}, onPreview = {},
        onSaveRecordingChange = {}, onConfirmCandidate = {},
        onCancelExit = {}, onConfirmExit = {}, onRequestRerecord = {},
        onCancelRerecord = {}, onConfirmRerecord = {}, onRequestDelete = {},
        onCancelDelete = {}, onConfirmDelete = {}
    ))
}
