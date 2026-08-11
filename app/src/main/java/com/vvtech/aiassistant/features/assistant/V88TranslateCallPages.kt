package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.features.assistant_translation.AssistantTranslateCallV88Page

@Composable
internal fun FinalTranslateCallPageV3Safe(
    phoneNumber: String,
    seconds: Int,
    status: TranslationCallStatusResponse?,
    error: String?,
    audioChannelStatus: String?,
    muted: Boolean,
    speakerEnabled: Boolean,
    panelCollapsed: Boolean,
    onMuteToggle: () -> Unit,
    onSpeakerToggle: () -> Unit,
    onPanelToggle: () -> Unit,
    onHangup: () -> Unit
) {
    AssistantTranslateCallV88Page(
        phoneNumber = phoneNumber,
        seconds = seconds,
        status = status,
        error = error,
        audioChannelStatus = audioChannelStatus,
        muted = muted,
        speakerEnabled = speakerEnabled,
        panelCollapsed = panelCollapsed,
        onMuteToggle = onMuteToggle,
        onSpeakerToggle = onSpeakerToggle,
        onPanelToggle = onPanelToggle,
        onHangup = onHangup
    )
}
