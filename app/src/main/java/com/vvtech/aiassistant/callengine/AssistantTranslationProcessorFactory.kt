package com.vvtech.aiassistant.callengine

internal object AssistantTranslationProcessorFactory {
    fun create(
        provider: String,
        myLanguage: String,
        peerLanguage: String,
        callbacks: AssistantTranslationProcessorCallbacks
    ): AssistantRealtimeTranslationProcessor {
        return if (provider.contains("doubao", ignoreCase = true)) {
            AssistantDoubaoTranslationProcessor(
                config = AssistantCallEngineConfiguration.doubao(),
                myLanguage = myLanguage,
                peerLanguage = peerLanguage,
                callbacks = callbacks
            )
        } else {
            AssistantQwenTranslationProcessor(
                config = AssistantCallEngineConfiguration.qwen(),
                myLanguage = myLanguage,
                peerLanguage = peerLanguage,
                callbacks = callbacks
            )
        }
    }
}
