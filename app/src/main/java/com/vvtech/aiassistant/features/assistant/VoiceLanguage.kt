package com.vvtech.aiassistant.features.assistant

import java.util.Locale

const val VoiceLanguagePrefsName = "index9_native_screen"
const val VoiceLanguageCodeKey = "voice_language_code"
const val DefaultVoiceLanguageCode = "zh-CN"

enum class VoiceLanguage(
    val code: String,
    val label: String,
    val settingsValue: String,
    val locale: Locale,
    val firstWelcome: String,
    val repeatWelcome: String,
    val standbyText: String,
    val listeningText: String,
    val aiSpeakingText: String,
    val aiThinkingText: String
) {
    Chinese(
        code = "zh-CN",
        label = "汉语",
        settingsValue = "汉语",
        locale = Locale.SIMPLIFIED_CHINESE,
        firstWelcome = "请按住下方语音按钮，说出你的需求。",
        repeatWelcome = "请按住下方语音按钮，说出你的需求。",
        standbyText = "请按住下方语音按钮，说出你的需求。",
        listeningText = "正在聆听...",
        aiSpeakingText = "AI 回复中...",
        aiThinkingText = "AI 思考中..."
    ),
    English(
        code = "en-US",
        label = "英语",
        settingsValue = "English",
        locale = Locale.US,
        firstWelcome = "Tell me what you need. I can help book a restaurant, hotel, flight, or make a call.",
        repeatWelcome = "Tell me what you need.",
        standbyText = "Tap to start a task",
        listeningText = "Listening...",
        aiSpeakingText = "AI is replying",
        aiThinkingText = "AI is thinking"
    ),
    Japanese(
        code = "ja-JP",
        label = "日语",
        settingsValue = "日本語",
        locale = Locale.JAPAN,
        firstWelcome = "こんにちは、AIアシスタントです。レストランやホテルの予約など、必要なことを話してください。",
        repeatWelcome = "ご要望をお話しください。",
        standbyText = "タップして依頼を開始",
        listeningText = "聞き取っています...",
        aiSpeakingText = "AI が返答しています",
        aiThinkingText = "AI が考えています"
    );

    companion object {
        fun fromCode(rawCode: String?): VoiceLanguage {
            val normalized = rawCode?.trim().orEmpty()
            return when {
                normalized.equals(English.code, ignoreCase = true) ||
                    normalized.equals("en", ignoreCase = true) -> English
                normalized.equals(Japanese.code, ignoreCase = true) ||
                    normalized.equals("ja", ignoreCase = true) ||
                    normalized.equals("jp", ignoreCase = true) -> Japanese
                else -> Chinese
            }
        }
    }
}
