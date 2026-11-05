package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalSettingsPageV3
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground

/** Effective settings home, synthetic summaries and no business callbacks. */
@Composable
fun SettingsReference() {
    PhoneFrameWithBackground {
        FinalSettingsPageV3(
            developerToolsVisible = true,
            onOpenDeveloperTools = {}, onOpenContactMethods = {},
            contactMethodCount = 0,
            realtimeProviderSummary = "QwenOmniPlus",
            realtimeProviderBillingMultiplier = 1.0,
            realtimeProviderLoading = false, realtimeProviderError = null,
            onOpenRealtimeProvider = {},
            translationProviderSummary = "设置",
            translationProviderLoading = false, translationProviderError = null,
            onOpenTranslationProvider = {},
            voiceCloneStatus = null, voiceCloneLoading = false,
            voiceCloneError = null, onOpenVoiceClone = {}
        )
    }
}
