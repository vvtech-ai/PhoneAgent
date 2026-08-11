package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.V88VoiceModelOptions
import com.vvtech.aiassistant.features.assistant.toRealtimeCallProviderValue
import com.vvtech.aiassistant.features.assistant.toVoiceModelComingSoonName

internal data class AssistantOverlayModelSelectionState(
    val selectedVoiceModelId: String,
    val availableVoiceModelIds: Set<String>,
    val realtimeProviderSwitching: Boolean
)

internal data class AssistantOverlayModelSelectionCallbacks(
    val onShowMessage: (String) -> Unit,
    val onShowVoiceModelSheetChange: (Boolean) -> Unit,
    val onSwitchRealtimeCallProvider: (String) -> Unit
)

internal fun handleOverlayVoiceModelSelection(
    modelId: String,
    state: AssistantOverlayModelSelectionState,
    callbacks: AssistantOverlayModelSelectionCallbacks
) {
    val option = V88VoiceModelOptions.firstOrNull { it.id == modelId }
    if (option?.enabled == false) {
        callbacks.onShowMessage("${option.title.toVoiceModelComingSoonName()}调试中，即将推出。")
        return
    }
    val provider = modelId.toRealtimeCallProviderValue()
    when {
        provider == null -> {
            callbacks.onShowMessage("该模型调试中，即将推出。")
        }
        !state.availableVoiceModelIds.contains(modelId) -> {
            callbacks.onShowMessage("当前模型暂不可用，请稍后重试。")
        }
        state.realtimeProviderSwitching -> {
            callbacks.onShowMessage("通话模型正在切换中")
        }
        modelId == state.selectedVoiceModelId -> {
            callbacks.onShowVoiceModelSheetChange(false)
        }
        else -> {
            callbacks.onShowVoiceModelSheetChange(false)
            callbacks.onSwitchRealtimeCallProvider(provider)
        }
    }
}
