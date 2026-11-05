package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.PhoneFrameWithBackground
import com.vvtech.aiassistant.features.assistant_settings.*
import com.vvtech.aiassistant.model.RealtimeCallProviderItem
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse

/** Catalog layout only; no model, voice, clone, media or account operations. */
@Composable
fun ModelsReference(onBack: () -> Unit) {
    val rows = listOf(
        RealtimeCallProviderItem(
            provider = "QWEN_OMNI_PLUS", displayName = "QwenOmniPlus",
            description = "合成模型一", active = true, configured = true,
            available = true, statusMessage = "", billingMultiplier = 1.0
        ),
        RealtimeCallProviderItem(
            provider = "DOUBAO", displayName = "Seeduplex",
            description = "合成模型二", active = false, configured = true,
            available = true, statusMessage = "", billingMultiplier = 2.0
        )
    )
    PhoneFrameWithBackground {
        AssistantRealtimeProviderPage(
            state = AssistantRealtimeProviderPageState(
                providerResponse = RealtimeCallProviderResponse(
                    activeProvider = "QWEN_OMNI_PLUS",
                    activeProviderDisplayName = "QwenOmniPlus",
                    source = "synthetic", updatedAt = null, providers = rows
                ),
                providerLoading = false, providerSwitching = false,
                providerError = null, hasAnyReadyVoiceClone = false,
                voiceSettings = AssistantRealtimeCallVoiceSettingsPageState(
                    response = null, loading = false, switching = false,
                    error = null, activeProvider = "QWEN_OMNI_PLUS",
                    cloneStatus = null, cloneCandidateReady = false,
                    cloneLoading = false, cloneActionLoading = false,
                    clonePreviewLoading = false, clonePreviewPlaying = false,
                    cloneError = null
                )
            ),
            callbacks = AssistantRealtimeProviderPageCallbacks(
                onBack = onBack, onRefreshProvider = {}, onRefreshVoice = {},
                onSelectProvider = {}, onOpenVoiceClone = {},
                onStartVoiceCloneForModel = {}, onSelectVoice = {},
                onSelectCloneVoice = {}, onPreviewCloneVoice = {},
                onStopCloneVoicePreview = {}, onDeleteCloneVoice = { _, _ -> }
            )
        )
    }
}
