package com.vvtech.aiassistant.callengine

import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.account.AccountIdentityProvider

internal object AssistantCallEngineConfiguration {
    fun qwen(): AssistantRealtimeModelConfig = AssistantRealtimeModelConfig(
        websocketUrl = backendWebSocketUrl("qwen"),
        apiKey = AccountIdentityProvider.accessToken,
        model = BuildConfig.ASSISTANT_QWEN_REALTIME_MODEL,
        voice = "Nofish",
        outputSampleRate = 24_000
    )

    fun doubao(): AssistantRealtimeModelConfig = AssistantRealtimeModelConfig(
        websocketUrl = backendWebSocketUrl("doubao"),
        apiKey = AccountIdentityProvider.accessToken,
        accessKey = "",
        model = BuildConfig.ASSISTANT_DOUBAO_REALTIME_RESOURCE_ID,
        outputSampleRate = 16_000
    )

    fun backendWebSocketUrl(provider: String): String =
        BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/') + "/ws/assistant/translation-model/$provider"

}
