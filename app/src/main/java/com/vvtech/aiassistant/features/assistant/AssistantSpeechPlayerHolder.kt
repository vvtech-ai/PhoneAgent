package com.vvtech.aiassistant.features.assistant

import android.content.Context

object AssistantSpeechPlayerHolder {

    @Volatile
    private var instance: AssistantSpeechPlayer? = null

    fun get(context: Context): AssistantSpeechPlayer {
        return instance ?: synchronized(this) {
            instance ?: AssistantSpeechPlayer(context.applicationContext).also { created ->
                instance = created
            }
        }
    }

    fun prewarm(context: Context) {
        get(context)
    }
}
