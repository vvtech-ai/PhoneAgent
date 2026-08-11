package com.vvtech.aiassistant.features.assistant_voice

import android.content.Context
import android.content.SharedPreferences
import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceLanguageCodeKey
import com.vvtech.aiassistant.features.assistant.VoiceLanguagePrefsName

internal class AssistantVoiceLanguageState(
    initialCode: String?,
    private val persistCode: (String) -> Unit = {}
) {
    constructor(context: Context) : this(
        context.getSharedPreferences(VoiceLanguagePrefsName, Context.MODE_PRIVATE)
    )

    private constructor(prefs: SharedPreferences) : this(
        initialCode = prefs.getString(VoiceLanguageCodeKey, DefaultVoiceLanguageCode),
        persistCode = { code ->
            prefs.edit().putString(VoiceLanguageCodeKey, code).apply()
        }
    )

    var code: String = VoiceLanguage.fromCode(initialCode ?: DefaultVoiceLanguageCode).code
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
}
