package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.Box
import com.vvtech.aiassistant.features.assistant_settings.*
import com.vvtech.aiassistant.model.RealtimeCallVoiceItem
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse

/** Capture only: the native sheet owns a player on preview clicks; do not click preview. */
@Composable
fun VoicesReference(onBack: () -> Unit) {
    Box {
        ModelsReference(onBack)
        AssistantRealtimeCallVoiceSettingsSheet(
            state = AssistantRealtimeCallVoiceSettingsPageState(
                response = RealtimeCallVoiceResponse(
                    activeVoice = "Andre", activeVoiceDisplayName = "Andre",
                    defaultVoice = "Andre", source = "synthetic", updatedAt = null,
                    voices = listOf("Andre", "Ethan", "Katerina").map { name ->
                        RealtimeCallVoiceItem(name, name, "合成样音", name == "Andre", name == "Andre")
                    }, selectionMode = "AI"
                ),
                loading = false, switching = false, error = null,
                activeProvider = "QWEN_OMNI_PLUS", cloneStatus = null,
                cloneCandidateReady = false, cloneLoading = false,
                cloneActionLoading = false, clonePreviewLoading = false,
                clonePreviewPlaying = false, cloneError = null
            ),
            callbacks = AssistantRealtimeCallVoiceSettingsPageCallbacks(
                onBack = onBack, onSelectVoice = {}, onSelectCloneVoice = {},
                onStartCloneVoice = {}, onPreviewCloneVoice = {},
                onStopCloneVoicePreview = {}, onDeleteClone = {}
            )
        )
    }
}
