package com.vvtech.aiassistant.features.assistant_voice

import android.content.Context
import com.vvtech.aiassistant.features.assistant.speech.TtsApiClient
import com.vvtech.aiassistant.features.assistant.speech.qwen.QwenTaskAsrSocketClient

internal data class TaskVoiceClients(
    val asrClient: TaskAsrClient,
    val ttsClient: TtsApiClient
)

internal object TaskVoiceClientFactory {
    fun create(context: Context): TaskVoiceClients {
        return TaskVoiceClients(
            asrClient = QwenTaskAsrSocketClient(context),
            ttsClient = TaskTtsClientFactory.create()
        )
    }
}
