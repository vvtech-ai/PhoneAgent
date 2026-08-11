package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse

internal fun RealtimeCallProviderResponse.toV88VoiceModelOptions(): List<V88VoiceModelOption> =
    providers.map { provider ->
        V88VoiceModelOption(
            id = normalizeAiCallModelId(provider.provider),
            title = AssistantCallModelDisplayNames
                .resolve(provider.provider, provider.displayName)
                ?: provider.displayName.trim(),
            subtitle = provider.description.orEmpty().trim(),
            enabled = provider.available
        )
    }

internal fun resolveV88VoiceModelOptions(
    response: RealtimeCallProviderResponse?
): List<V88VoiceModelOption> {
    val serverOptions = response?.toV88VoiceModelOptions()
        .orEmpty()
        .filter { it.id in SHARED_AI_CALL_MODEL_IDS }
    if (serverOptions.isNotEmpty()) {
        return serverOptions
    }
    val availableModelIds = response?.providers
        ?.filter { it.available }
        ?.map { normalizeAiCallModelId(it.provider) }
        ?.toSet()
        .orEmpty()
    return V88VoiceModelOptions
        .filter { it.id in SHARED_AI_CALL_MODEL_IDS }
        .map { option ->
            option.copy(enabled = option.enabled && option.id in availableModelIds)
        }
}

private val SHARED_AI_CALL_MODEL_IDS = setOf(
    "QWEN_OMNI_PLUS",
    "DOUBAO",
    "DOUBAO_SEEDUPLEX_3_0"
)

internal fun normalizeAiCallModelId(provider: String): String =
    if (provider.equals("QWEN_OMNI_FLASH", ignoreCase = true)) {
        "QWEN_OMNI_PLUS"
    } else {
        provider
    }
