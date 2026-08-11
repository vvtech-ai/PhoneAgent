package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.speech.TtsApiClient
import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskTtsApiClient

internal object TaskTtsClientFactory {
    fun create(): TtsApiClient {
        return QwenTaskTtsApiClient()
    }
}
