package com.vvtech.aiassistant.callengine

internal data class AssistantTranslationTranscript(
    val id: String,
    val speaker: String,
    val sourceLanguage: String,
    val sourceText: String,
    val translatedLanguage: String,
    val translatedText: String,
    val final: Boolean
)

internal interface AssistantRealtimeTranslationProcessor : AutoCloseable {
    val translatedAudioCompletionSupported: Boolean
        get() = false
    val originalAudioDynamicBoostEnabled: Boolean
        get() = true
    fun start()
    fun onLocalPcm16k(pcm16k: ShortArray)
    fun onRemotePcm16k(pcm16k: ShortArray)
    fun setIntroTriggerResponseListener(listener: () -> Unit): Boolean = false
}

internal data class AssistantRealtimeModelConfig(
    val websocketUrl: String,
    val apiKey: String,
    val accessKey: String = "",
    val model: String,
    val voice: String = "Nofish",
    val outputSampleRate: Int = 16_000
) {
    val configured: Boolean
        get() = websocketUrl.isNotBlank() && apiKey.isNotBlank()
}

internal data class AssistantTranslationProcessorCallbacks(
    val onTranscript: (AssistantTranslationTranscript) -> Unit,
    val onTranslatedAudioToSip: (ShortArray) -> Unit,
    val onTranslatedAudioToLocal: (ShortArray) -> Unit,
    val onError: (String) -> Unit,
    val onReady: () -> Unit = {},
    val onTranslatedAudioToSipCompleted: () -> Unit = {},
    val onTranslatedAudioToLocalCompleted: () -> Unit = {}
)
