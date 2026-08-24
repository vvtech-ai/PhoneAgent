package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse

internal fun RealtimeCallProviderResponse.toV88VoiceModelOptions(): List<V88VoiceModelOption> =
    providers.map { provider ->
        V88VoiceModelOption(
            id = normalizeAiCallModelId(provider.provider),
            title = AssistantCallModelDisplayNames
                .resolve(provider.provider, provider.displayName)
                ?: provider.displayName.trim(),
            subtitle = localizedAiCallModelDescription(
                id = normalizeAiCallModelId(provider.provider),
                fallback = provider.description.orEmpty().trim()
            ),
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
            option.copy(
                subtitle = localizedAiCallModelDescription(option.id, option.subtitle),
                enabled = option.enabled && option.id in availableModelIds
            )
        }
}

private fun localizedAiCallModelDescription(id: String, fallback: String): String {
    return when (id) {
        "QWEN_OMNI_PLUS" -> currentAppText(
            "阿里巴巴 · 全双工语音对话引擎",
            "Alibaba · Full-duplex conversational voice engine"
        )
        "DOUBAO" -> currentAppText(
            "字节跳动 · 端到端双工语音模型",
            "ByteDance · End-to-end full-duplex voice model"
        )
        "GPT" -> currentAppText("GPT 实时语音模型", "GPT realtime voice model")
        else -> fallback
    }
}

private val SHARED_AI_CALL_MODEL_IDS = setOf(
    "QWEN_OMNI_PLUS",
    "DOUBAO"
)

internal fun normalizeAiCallModelId(provider: String): String =
    if (provider.equals("QWEN_OMNI_FLASH", ignoreCase = true)) {
        "QWEN_OMNI_PLUS"
    } else {
        provider
    }
