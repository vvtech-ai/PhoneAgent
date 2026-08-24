package com.vvtech.aiassistant.features.assistant_voice

import android.content.Context
import android.content.SharedPreferences
import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceLanguageCodeKey
import com.vvtech.aiassistant.features.assistant.VoiceLanguageEnglishDefaultMigrationKey
import com.vvtech.aiassistant.features.assistant.VoiceLanguagePrefsName
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguageManager

internal class AssistantVoiceLanguageState(
    initialCode: String?,
    private val persistCode: (String) -> Unit = {}
) {
    constructor(context: Context) : this(
        context.getSharedPreferences(VoiceLanguagePrefsName, Context.MODE_PRIVATE)
    )

    private constructor(prefs: SharedPreferences) : this(
        initialCode = initialVoiceLanguageCode(prefs),
        persistCode = { code ->
            prefs.edit()
                .putString(VoiceLanguageCodeKey, code)
                .putBoolean(VoiceLanguageEnglishDefaultMigrationKey, true)
                .apply()
        }
    )

    var code: String = VoiceLanguage.fromCode(
        initialCode?.takeIf(::isSupportedLanguageCode) ?: DefaultVoiceLanguageCode
    ).code
        private set

    val language: VoiceLanguage
        get() = VoiceLanguage.fromCode(code)

    fun set(languageCode: String): Boolean {
        val normalized = VoiceLanguage.fromCode(languageCode).code
        if (code == normalized) {
            return false
        }
        code = normalized
        persistCode(normalized)
        return true
    }

    private companion object {
        fun isSupportedLanguageCode(code: String): Boolean {
            val normalized = code.trim()
            return normalized.equals("en", ignoreCase = true) ||
                normalized.equals(VoiceLanguage.English.code, ignoreCase = true) ||
                normalized.equals("zh", ignoreCase = true) ||
                normalized.equals(VoiceLanguage.Chinese.code, ignoreCase = true) ||
                normalized.equals("ja", ignoreCase = true) ||
                normalized.equals("jp", ignoreCase = true) ||
                normalized.equals(VoiceLanguage.Japanese.code, ignoreCase = true)
        }

        fun initialVoiceLanguageCode(prefs: SharedPreferences): String {
            val storedCode = prefs.getString(VoiceLanguageCodeKey, null)
            val migrationDone = prefs.getBoolean(VoiceLanguageEnglishDefaultMigrationKey, false)
            val shouldMigrateToEnglish =
                !migrationDone &&
                    AppLanguageManager.currentAppLanguage() == AppLanguage.English &&
                    (storedCode.isNullOrBlank() || VoiceLanguage.fromCode(storedCode) == VoiceLanguage.Chinese)

            if (shouldMigrateToEnglish) {
                prefs.edit()
                    .putString(VoiceLanguageCodeKey, VoiceLanguage.English.code)
                    .putBoolean(VoiceLanguageEnglishDefaultMigrationKey, true)
                    .apply()
                return VoiceLanguage.English.code
            }

            return storedCode ?: DefaultVoiceLanguageCode
        }
    }
}
