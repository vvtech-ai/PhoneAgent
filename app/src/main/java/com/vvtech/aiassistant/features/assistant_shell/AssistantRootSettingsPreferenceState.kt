package com.vvtech.aiassistant.features.assistant_shell

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.DefaultTranslationCalleeLanguage
import com.vvtech.aiassistant.features.assistant.DefaultTranslationCallerLanguage
import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalDefaultPureVoiceMode
import com.vvtech.aiassistant.features.assistant.FinalTranslationQwenCalleeLanguageKey
import com.vvtech.aiassistant.features.assistant.FinalTranslationQwenCallerLanguageKey
import com.vvtech.aiassistant.features.assistant.FinalTranslationQwenVoiceKey
import com.vvtech.aiassistant.features.assistant.FinalVoiceLanguageCodeKey
import com.vvtech.aiassistant.features.assistant.TranslationProviderLanguageSettings
import com.vvtech.aiassistant.features.assistant.TranslationProviderLanguageSettingsSaver
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.sanitizeTranslationProviderLanguageSettings
import com.vvtech.aiassistant.features.assistant.sanitizeTranslationQwenVoice
import com.vvtech.aiassistant.features.assistant_settings.DefaultDomesticSipAccountId
import com.vvtech.aiassistant.features.assistant_settings.DefaultInternationalSipAccountId
import com.vvtech.aiassistant.features.assistant_settings.DomesticSipAccountPreferenceKey
import com.vvtech.aiassistant.features.assistant_settings.InternationalSipAccountPreferenceKey
import com.vvtech.aiassistant.features.assistant_settings.normalizeDomesticSipAccountId
import com.vvtech.aiassistant.features.assistant_settings.normalizeInternationalSipAccountId

internal interface AssistantRootSettingsPreferenceStore {
    fun getBoolean(key: String, defaultValue: Boolean): Boolean
    fun putBoolean(key: String, value: Boolean)
    fun getString(key: String, defaultValue: String?): String?
    fun putString(key: String, value: String)
}

internal class SharedPreferencesAssistantRootSettingsPreferenceStore(
    private val prefs: SharedPreferences
) : AssistantRootSettingsPreferenceStore {
    override fun getBoolean(key: String, defaultValue: Boolean): Boolean =
        prefs.getBoolean(key, defaultValue)

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun getString(key: String, defaultValue: String?): String? =
        prefs.getString(key, defaultValue)

    override fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }
}

internal class AssistantRootSettingsPreferenceState(
    private val store: AssistantRootSettingsPreferenceStore,
    developerModeEnabledState: MutableState<Boolean>,
    developerDataModeNameState: MutableState<String>,
    translationQwenVoicePreferenceState: MutableState<String>,
    translationQwenLanguageSettingsState: MutableState<TranslationProviderLanguageSettings>,
    pureVoiceModeState: MutableState<Boolean>,
    voiceLanguageCodeState: MutableState<String>,
    selectedDomesticSipAccountIdState: MutableState<String>,
    selectedInternationalSipAccountIdState: MutableState<String>
) {
    var developerModeEnabled: Boolean by developerModeEnabledState
        private set
    var developerDataModeName: String by developerDataModeNameState
        private set
    var translationQwenVoicePreference: String by translationQwenVoicePreferenceState
        private set
    var translationQwenLanguageSettings: TranslationProviderLanguageSettings by translationQwenLanguageSettingsState
        private set
    var pureVoiceMode: Boolean by pureVoiceModeState
    var voiceLanguageCode: String by voiceLanguageCodeState
    var selectedDomesticSipAccountId: String by selectedDomesticSipAccountIdState
        private set
    var selectedInternationalSipAccountId: String by selectedInternationalSipAccountIdState
        private set

    val voiceLanguage: VoiceLanguage
        get() = VoiceLanguage.fromCode(voiceLanguageCode)

    fun enableDeveloperMode(): Boolean {
        if (developerModeEnabled) return false
        developerModeEnabled = true
        return true
    }

    fun applyDeveloperDataMode(mode: DeveloperDataMode) {
        developerDataModeName = mode.name
    }

    fun updateTranslationQwenVoicePreference(rawVoice: String) {
        val sanitized = sanitizeTranslationQwenVoice(rawVoice)
        translationQwenVoicePreference = sanitized
        store.putString(FinalTranslationQwenVoiceKey, sanitized)
    }

    fun updateTranslationQwenLanguageSettings(settings: TranslationProviderLanguageSettings) {
        val sanitized = sanitizeTranslationProviderLanguageSettings(
            callerLanguage = settings.callerLanguage,
            calleeLanguage = settings.calleeLanguage
        )
        translationQwenLanguageSettings = sanitized
        store.putString(FinalTranslationQwenCallerLanguageKey, sanitized.callerLanguage)
        store.putString(FinalTranslationQwenCalleeLanguageKey, sanitized.calleeLanguage)
    }

    fun updateDomesticSipAccountId(rawId: String) {
        val normalized = normalizeDomesticSipAccountId(rawId)
        selectedDomesticSipAccountId = normalized
        store.putString(DomesticSipAccountPreferenceKey, normalized)
    }

    fun updateInternationalSipAccountId(rawId: String) {
        val normalized = normalizeInternationalSipAccountId(rawId)
        selectedInternationalSipAccountId = normalized
        store.putString(InternationalSipAccountPreferenceKey, normalized)
    }
}

@Composable
internal fun rememberAssistantRootSettingsPreferenceState(
    prefs: SharedPreferences
): AssistantRootSettingsPreferenceState {
    val store = remember(prefs) { SharedPreferencesAssistantRootSettingsPreferenceStore(prefs) }
    val developerModeEnabledState = remember {
        mutableStateOf(false)
    }
    val developerDataModeNameState = rememberSaveable {
        mutableStateOf(DeveloperDataMode.Empty.name)
    }
    val translationQwenVoicePreferenceState = rememberSaveable {
        mutableStateOf(
            sanitizeTranslationQwenVoice(store.getString(FinalTranslationQwenVoiceKey, "Nofish"))
        )
    }
    val translationQwenLanguageSettingsState = rememberSaveable(
        stateSaver = TranslationProviderLanguageSettingsSaver
    ) {
        mutableStateOf(
            sanitizeTranslationProviderLanguageSettings(
                callerLanguage = store.getString(
                    FinalTranslationQwenCallerLanguageKey,
                    DefaultTranslationCallerLanguage
                ),
                calleeLanguage = store.getString(
                    FinalTranslationQwenCalleeLanguageKey,
                    DefaultTranslationCalleeLanguage
                )
            )
        )
    }
    val pureVoiceModeState = rememberSaveable {
        mutableStateOf(FinalDefaultPureVoiceMode)
    }
    val voiceLanguageCodeState = rememberSaveable {
        mutableStateOf(
            store.getString(FinalVoiceLanguageCodeKey, DefaultVoiceLanguageCode)
                ?: DefaultVoiceLanguageCode
        )
    }
    val selectedDomesticSipAccountIdState = rememberSaveable {
        mutableStateOf(
            normalizeDomesticSipAccountId(
                store.getString(DomesticSipAccountPreferenceKey, DefaultDomesticSipAccountId)
            )
        )
    }
    val selectedInternationalSipAccountIdState = rememberSaveable {
        mutableStateOf(
            normalizeInternationalSipAccountId(
                store.getString(InternationalSipAccountPreferenceKey, DefaultInternationalSipAccountId)
            )
        )
    }
    return remember(
        store,
        developerModeEnabledState,
        developerDataModeNameState,
        translationQwenVoicePreferenceState,
        translationQwenLanguageSettingsState,
        pureVoiceModeState,
        voiceLanguageCodeState,
        selectedDomesticSipAccountIdState,
        selectedInternationalSipAccountIdState
    ) {
        AssistantRootSettingsPreferenceState(
            store = store,
            developerModeEnabledState = developerModeEnabledState,
            developerDataModeNameState = developerDataModeNameState,
            translationQwenVoicePreferenceState = translationQwenVoicePreferenceState,
            translationQwenLanguageSettingsState = translationQwenLanguageSettingsState,
            pureVoiceModeState = pureVoiceModeState,
            voiceLanguageCodeState = voiceLanguageCodeState,
            selectedDomesticSipAccountIdState = selectedDomesticSipAccountIdState,
            selectedInternationalSipAccountIdState = selectedInternationalSipAccountIdState
        )
    }
}
