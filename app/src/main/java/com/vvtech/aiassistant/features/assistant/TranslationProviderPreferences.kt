package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver
import com.vvtech.aiassistant.core.model.StartTranslationCallRequest
import com.vvtech.aiassistant.core.model.TranslationLanguageMode
import com.vvtech.aiassistant.core.model.TranslationVoiceMode
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.features.translation_call.ui.TranslationProviderUiCatalog

internal data class TranslationLanguageChoice(
    val code: String,
    val label: String
)

internal data class TranslationProviderLanguageSettings(
    val callerLanguage: String = DefaultTranslationCallerLanguage,
    val calleeLanguage: String = DefaultTranslationCalleeLanguage
)

internal val TranslationProviderLanguageSettingsSaver: Saver<TranslationProviderLanguageSettings, Any> = listSaver(
    save = { settings ->
        listOf(settings.callerLanguage, settings.calleeLanguage)
    },
    restore = { restored ->
        sanitizeTranslationProviderLanguageSettings(
            callerLanguage = restored.getOrNull(0) as? String,
            calleeLanguage = restored.getOrNull(1) as? String
        )
    }
)

internal const val DefaultTranslationCallerLanguage = "zh"
internal const val DefaultTranslationCalleeLanguage = "en"

internal val TranslationProviderLanguageChoices = listOf(
    TranslationLanguageChoice("zh", "中文"),
    TranslationLanguageChoice("en", "English"),
    TranslationLanguageChoice("ja", "日本語"),
    TranslationLanguageChoice("ko", "한국어"),
    TranslationLanguageChoice("fr", "Français"),
    TranslationLanguageChoice("de", "Deutsch"),
    TranslationLanguageChoice("es", "Español"),
    TranslationLanguageChoice("ru", "Русский"),
    TranslationLanguageChoice("ar", "العربية")
)

internal fun sanitizeTranslationProviderLanguageSettings(
    callerLanguage: String?,
    calleeLanguage: String?
): TranslationProviderLanguageSettings {
    return TranslationProviderLanguageSettings(
        callerLanguage = sanitizeTranslationLanguageCode(callerLanguage, DefaultTranslationCallerLanguage),
        calleeLanguage = sanitizeTranslationLanguageCode(calleeLanguage, DefaultTranslationCalleeLanguage)
    )
}

internal fun translationLanguageLabel(code: String?): String {
    val normalizedCode = code?.trim().orEmpty()
    return TranslationProviderLanguageChoices.firstOrNull {
        it.code.equals(normalizedCode, ignoreCase = true)
    }?.label ?: normalizedCode.ifBlank { DefaultTranslationCallerLanguage }
}

internal fun buildTranslationStartRequest(
    userId: String,
    phoneNumber: String,
    displayName: String?,
    translationProvider: String?,
    qwenVoicePreference: String?,
    languageSettings: TranslationProviderLanguageSettings
): StartTranslationCallRequest {
    val usingQwen =
        TranslationProviderUiCatalog.option(translationProvider)?.provider ==
            TranslationRealtimeProvider.Qwen
    val sanitizedLanguages = sanitizeTranslationProviderLanguageSettings(
        callerLanguage = languageSettings.callerLanguage,
        calleeLanguage = languageSettings.calleeLanguage
    )
    return StartTranslationCallRequest(
        userId = userId,
        phoneNumber = phoneNumber,
        displayName = displayName,
        languageMode = if (usingQwen) TranslationLanguageMode.MANUAL else TranslationLanguageMode.AUTO,
        callerPreferredLanguage = if (usingQwen) sanitizedLanguages.callerLanguage else null,
        calleePreferredLanguage = if (usingQwen) sanitizedLanguages.calleeLanguage else null,
        voiceMode = TranslationVoiceMode.DEFAULT,
        preferredVoice = if (usingQwen) sanitizeQwenTranslationVoicePreference(qwenVoicePreference) else null
    )
}

private fun sanitizeTranslationLanguageCode(raw: String?, fallback: String): String {
    val normalized = raw?.trim().orEmpty()
    return TranslationProviderLanguageChoices.firstOrNull {
        it.code.equals(normalized, ignoreCase = true)
    }?.code ?: fallback
}

private fun sanitizeQwenTranslationVoicePreference(raw: String?): String {
    return when (raw?.trim()) {
        "Nofish" -> "Nofish"
        else -> "Nofish"
    }
}
