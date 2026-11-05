package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.*
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_translation.*

/** Local reference controls only; no preferences, media or translation service. */
@Composable
fun OriginalAudioReference(onBack: () -> Unit) {
    var state by remember { mutableStateOf(DomesticOriginalAudioSettingsState(
        enabled = true, gainPercent = 50, volumePercent = 100
    )) }
    PhoneFrameWithBackground {
        DomesticOriginalAudioSettingsPage(
            state = state,
            callbacks = DomesticOriginalAudioSettingsCallbacks(
                onEnabledChange = { state = state.copy(enabled = it) },
                onGainPercentChange = { state = state.copy(gainPercent = it) },
                onVolumePercentChange = { state = state.copy(volumePercent = it) }
            ),
            onBack = onBack
        )
    }
}
