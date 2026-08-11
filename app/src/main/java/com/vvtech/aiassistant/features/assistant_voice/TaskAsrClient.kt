package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.TaskVoiceAsrEvent

internal interface TaskAsrClient {
    fun start(
        languageCode: String = DefaultVoiceLanguageCode,
        startReason: String,
        onEvent: (TaskVoiceAsrEvent) -> Unit
    )

    fun stop()

    fun release()

    fun closeNow(reason: String = "manual")
}
