package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_translation.AssistantTranslationProviderSettingsPage
import com.vvtech.aiassistant.features.assistant_translation.DomesticOriginalAudioSettingsCallbacks
import com.vvtech.aiassistant.features.assistant_translation.DomesticOriginalAudioSettingsState
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse

internal fun normalizeTranslationSettingsCardValue(text: String): String {
    val trimmed = text.trim()
    if (trimmed.isBlank()) {
        return trimmed
    }
    val arrowTokens = listOf("閳?", "闁?", "闂?", "鈥?", "鈻?")
    if (trimmed in arrowTokens) {
        return "\u2192"
    }
    var normalized = trimmed
    arrowTokens.forEach { token ->
        if (normalized.endsWith(" $token")) {
            normalized = normalized.removeSuffix(" $token").trimEnd() + " \u2192"
        }
    }
    return normalized
}

internal fun formatVoiceModelCardValue(title: String): String {
    val trimmed = title.trim()
    if (trimmed.isBlank()) {
        return "\u203a"
    }
    val prefix = if (trimmed.first().isLetterOrDigit() && trimmed.first().code < 128) {
        trimmed.takeWhile { it.isLetterOrDigit() }.ifBlank { trimmed }.take(8)
    } else {
        trimmed.take(4)
    }
    return "$prefix\u2026 \u203a"
}

internal fun sanitizeTranslationSettingsUiDisplayTextFinal(text: String): String {
    return when {
        text.contains("鐎圭偞妞傜紙鏄忕槯") -> "\u5b9e\u65f6\u7ffb\u8bd1\u901a\u8bdd"
        text.contains("閻庡湱鍋") -> "\u5b9e\u65f6\u7ffb\u8bd1\u901a\u8bdd"
        text.contains("闁诲骸婀遍崑") -> "\u5b9e\u65f6\u7ffb\u8bd1\u901a\u8bdd"
        text.contains("闂佽楠稿﹢閬嶅磻") -> "\u5b9e\u65f6\u7ffb\u8bd1\u901a\u8bdd"
        text.contains("鐠炲棗瀵?ATS") -> "\u8c46\u5305 ATS \u5b9e\u65f6\u7ffb\u8bd1"
        text.contains("閻犵偛妫楃€?ATS") -> "\u8c46\u5305 ATS \u5b9e\u65f6\u7ffb\u8bd1"
        text.contains("闁荤姷鍋涘Λ妤冣偓?ATS") -> "\u8c46\u5305 ATS \u5b9e\u65f6\u7ffb\u8bd1"
        text.contains("\u963f\u91cc Qwen") -> "\u5343\u95ee Qwen \u5b9e\u65f6\u540c\u4f20"
        text.contains("闃块噷 Qwen") -> "\u5343\u95ee Qwen \u5b9e\u65f6\u540c\u4f20"
        text.contains("闂冨潡鍣?Qwen") -> "\u5343\u95ee Qwen \u5b9e\u65f6\u540c\u4f20"
        text.contains("闂傚啫娼￠崳?Qwen") -> "\u5343\u95ee Qwen \u5b9e\u65f6\u540c\u4f20"
        text.contains("闂傚倸鍟锟犲闯?Qwen") -> "\u5343\u95ee Qwen \u5b9e\u65f6\u540c\u4f20"
        text == "閳?" || text == "闁?" || text == "闂?" -> "\u2192"
        text.endsWith(" 閳?") -> text.removeSuffix(" 閳?") + " \u2192"
        text.endsWith(" 闁?") -> text.removeSuffix(" 闁?") + " \u2192"
        text.endsWith(" 闂?") -> text.removeSuffix(" 闂?") + " \u2192"
        else -> text
    }
}

internal fun qwenVoiceLabel(voice: String): String {
    return when (voice) {
        "Cherry" -> "\u5973\u58f0"
        "Nofish" -> "\u7537\u58f0"
        else -> voice
    }
}

@Composable
internal fun FinalTranslationProviderPageV3Safe(
    providerResponse: RealtimeTranslationProviderResponse?,
    loading: Boolean,
    switching: Boolean,
    error: String?,
    preferredQwenVoice: String,
    qwenLanguageSettings: TranslationProviderLanguageSettings,
    originalAudioState: DomesticOriginalAudioSettingsState,
    originalAudioCallbacks: DomesticOriginalAudioSettingsCallbacks,
    onSelectQwenVoice: (String) -> Unit,
    onSelectCallerLanguage: (String) -> Unit,
    onSelectCalleeLanguage: (String) -> Unit,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onSelectProvider: (String) -> Unit
) {
    AssistantTranslationProviderSettingsPage(
        providerResponse = providerResponse,
        loading = loading,
        switching = switching,
        error = error,
        preferredQwenVoice = preferredQwenVoice,
        qwenLanguageSettings = qwenLanguageSettings,
        originalAudioState = originalAudioState,
        originalAudioCallbacks = originalAudioCallbacks,
        onSelectQwenVoice = onSelectQwenVoice,
        onSelectCallerLanguage = onSelectCallerLanguage,
        onSelectCalleeLanguage = onSelectCalleeLanguage,
        onBack = onBack,
        onRefresh = onRefresh,
        onSelectProvider = onSelectProvider
    )
}
