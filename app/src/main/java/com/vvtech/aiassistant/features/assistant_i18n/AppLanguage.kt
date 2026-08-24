package com.vvtech.aiassistant.features.assistant_i18n

import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

enum class AppLanguage(
    val languageTag: String,
    val flag: String
) {
    English(
        languageTag = "en",
        flag = "\uD83C\uDDFA\uD83C\uDDF8"
    ),
    SimplifiedChinese(
        languageTag = "zh-CN",
        flag = "\uD83C\uDDE8\uD83C\uDDF3"
    );

    val code: String
        get() = languageTag

    companion object {
        val Chinese: AppLanguage
            get() = SimplifiedChinese

        fun fromCode(rawCode: String?): AppLanguage {
            return fromStoredLanguageTagOrNull(rawCode) ?: English
        }

        fun fromStoredLanguageTagOrNull(rawCode: String?): AppLanguage? {
            val normalized = rawCode?.trim().orEmpty()
            return when {
                normalized.equals(SimplifiedChinese.languageTag, ignoreCase = true) ||
                    normalized.equals("zh", ignoreCase = true) ||
                    normalized.equals("zh-CN", ignoreCase = true) ||
                    normalized.equals("cn", ignoreCase = true) -> SimplifiedChinese
                normalized.equals(English.languageTag, ignoreCase = true) ||
                    normalized.equals("en-US", ignoreCase = true) -> English
                else -> null
            }
        }

        fun isSupported(rawCode: String?): Boolean {
            return fromStoredLanguageTagOrNull(rawCode) != null
        }
    }
}

object AppLanguageManager {
    fun ensureSupportedDefaultLanguage(): AppLanguage {
        val languageTags = AppCompatDelegate.getApplicationLocales().toLanguageTags()
        if (!AppLanguage.isSupported(languageTags)) {
            setAppLanguage(AppLanguage.English)
            return AppLanguage.English
        }
        return AppLanguage.fromCode(languageTags)
    }

    fun currentAppLanguage(): AppLanguage {
        val languageTags = AppCompatDelegate.getApplicationLocales().toLanguageTags()
        return AppLanguage.fromCode(languageTags)
    }

    fun setAppLanguage(language: AppLanguage) {
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags(language.languageTag)
        )
    }
}

internal fun String.appText(language: AppLanguage, english: String): String =
    if (language == AppLanguage.English) english else this

internal fun currentAppText(chinese: String, english: String): String =
    chinese.appText(AppLanguageManager.currentAppLanguage(), english)
