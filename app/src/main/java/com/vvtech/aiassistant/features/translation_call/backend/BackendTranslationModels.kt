package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import java.io.IOException

internal data class BackendCreateCallRequest(
    val merchantPhone: String,
    val userLanguage: String,
    val merchantLanguage: String,
    val userId: String,
    val realtimeProvider: String,
    val voiceProvider: String = "twilio",
    val mediaTransports: List<String> = BackendMediaTransport.DefaultOrder,
    val originalAudioEnabled: Boolean = false,
    val originalAudioPercent: Int = 0,
    val originalAudioVolumePercent: Int = 100
)

internal data class BackendTranslationCallSession(
    val callSessionId: String,
    val status: String,
    val appAudioWsUrl: String,
    val mediaTransport: String,
    val liveKit: BackendLiveKitConnection?,
    val voiceProvider: String,
    val realtimeProvider: String,
    val environment: TranslationCallEnvironmentPatch?,
    val originalAudioEnabled: Boolean = false,
    val originalAudioPercent: Int = 0,
    val originalAudioVolumePercent: Int = 100
)

internal data class BackendLiveKitConnection(
    val url: String,
    val token: String,
    val roomName: String,
    val participantIdentity: String
)

internal data class BackendStartMerchantCallRequest(
    val callSessionId: String,
    val merchantPhone: String,
    val voiceProvider: String,
    val userId: String
)

internal data class BackendStartMerchantCallResult(
    val started: Boolean,
    val environment: TranslationCallEnvironmentPatch?
)

internal data class BackendHangupRequest(
    val callSessionId: String,
    val userId: String
)

internal data class BackendTranslationLanguage(
    val code: String,
    val label: String
)

internal data class BackendTranslationLanguageCatalog(
    val languages: List<BackendTranslationLanguage>
)

internal object BackendTranslationLanguageMapper {
    const val UnsupportedMessage = "当前后端实时翻译路线暂不支持该语言组合"

    fun resolve(
        value: String,
        catalog: BackendTranslationLanguageCatalog
    ): BackendTranslationLanguage {
        val normalized = normalize(value)
        return catalog.languages.firstOrNull {
            it.code.equals(normalized, ignoreCase = true) ||
                it.code.equals(value.trim(), ignoreCase = true) ||
                it.label.equals(value.trim(), ignoreCase = true)
        } ?: throw IllegalArgumentException(UnsupportedMessage)
    }

    private fun normalize(value: String): String = when (value.trim().lowercase()) {
        "中文", "汉语", "普通话", "chinese", "mandarin", "mandarin chinese",
        "zh", "zh-cn" -> "zh-CN"
        "英语", "英文", "english", "en", "en-us" -> "en-US"
        "日语", "日文", "japanese", "ja", "ja-jp" -> "ja-JP"
        else -> value.trim()
    }
}

internal object BackendMediaTransport {
    const val LiveKit = "livekit"
    const val WebSocket = "websocket"
    val DefaultOrder = listOf(LiveKit, WebSocket)
}

internal object BackendOriginalAudioRequestPolicy {
    const val DefaultVolumePercent = 100

    fun enabled(
        playOriginalAudio: Boolean,
        originalAudioGainPercent: Int,
        originalAudioVolumePercent: Int
    ): Boolean = playOriginalAudio &&
        (originalAudioGainPercent > 0 || originalAudioVolumePercent > 0)

    fun percent(playOriginalAudio: Boolean, originalAudioGainPercent: Int): Int =
        if (playOriginalAudio) {
            originalAudioGainPercent.coerceIn(MinPercent, MaxPercent)
        } else {
            0
        }

    fun volumePercent(raw: Int): Int = raw.coerceIn(0, DefaultVolumePercent)

    private const val MinPercent = 0
    private const val MaxPercent = 50
}

internal object BackendRealtimeProviderMapper {
    fun toApiValue(provider: TranslationRealtimeProvider): String = when (provider) {
        TranslationRealtimeProvider.OpenAi -> "openai"
        TranslationRealtimeProvider.Gemini -> "google-gemini-live-translate"
        TranslationRealtimeProvider.Qwen -> "qwen3.5-livetranslate-flash-realtime"
        TranslationRealtimeProvider.Doubao -> "doubao"
    }
}

internal class BackendTranslationHttpException(
    val statusCode: Int,
    val code: String,
    val environment: TranslationCallEnvironmentPatch?,
    message: String
) : IOException(message)

internal interface BackendTranslationClient {
    fun loadLanguageCatalog(): BackendTranslationLanguageCatalog
    fun createSession(request: BackendCreateCallRequest): BackendTranslationCallSession
    fun startMerchantCall(
        request: BackendStartMerchantCallRequest
    ): BackendStartMerchantCallResult
    fun hangup(request: BackendHangupRequest)
}
