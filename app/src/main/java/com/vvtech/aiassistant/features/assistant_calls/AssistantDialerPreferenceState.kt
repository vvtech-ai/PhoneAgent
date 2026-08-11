package com.vvtech.aiassistant.features.assistant_calls

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue

internal interface DialerPreferenceStore {
    fun getBoolean(key: String, default: Boolean): Boolean
    fun getString(key: String, default: String): String
    fun putBoolean(key: String, value: Boolean)
    fun putString(key: String, value: String)
}

private class SharedPreferencesDialerPreferenceStore(
    private val prefs: SharedPreferences
) : DialerPreferenceStore {
    override fun getBoolean(key: String, default: Boolean): Boolean {
        return prefs.getBoolean(key, default)
    }

    override fun getString(key: String, default: String): String {
        return prefs.getString(key, default) ?: default
    }

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }
}

internal class AssistantDialerPreferenceState(
    private val store: DialerPreferenceStore? = null,
    private val translateEnabledState: MutableState<Boolean> = mutableStateOf(true),
    private val promptBeforeCallState: MutableState<Boolean> = mutableStateOf(true),
    private val myLanguageState: MutableState<String> = mutableStateOf("中文"),
    private val otherLanguageState: MutableState<String> = mutableStateOf("英文"),
    private val normalCountryState: MutableState<String> = mutableStateOf("CN"),
    private val translationCountryState: MutableState<String> = mutableStateOf("CN"),
    private val locationPromptShownState: MutableState<Boolean> = mutableStateOf(false),
    private val locationSystemPermissionRequestedState: MutableState<Boolean> = mutableStateOf(false),
    private val callLogPermissionRequestedState: MutableState<Boolean> = mutableStateOf(false)
) {
    var translateEnabled: Boolean
        get() = translateEnabledState.value
        set(value) {
            translateEnabledState.value = value
            store?.putBoolean(TranslateEnabledKey, value)
        }
    var promptBeforeCall: Boolean
        get() = promptBeforeCallState.value
        set(value) {
            promptBeforeCallState.value = value
            store?.putBoolean(PromptBeforeCallKey, value)
        }
    var myLanguage: String
        get() = myLanguageState.value
        set(value) {
            myLanguageState.value = value
            store?.putString(MyLanguageKey, value)
        }
    var otherLanguage: String
        get() = otherLanguageState.value
        set(value) {
            otherLanguageState.value = value
            store?.putString(OtherLanguageKey, value)
        }

    val selectedCountryIso: String
        get() = countryIso(translateEnabled)
    var locationPromptShown: Boolean
        get() = locationPromptShownState.value
        set(value) {
            locationPromptShownState.value = value
            store?.putBoolean(LocationPromptShownKey, value)
        }
    var locationSystemPermissionRequested: Boolean
        get() = locationSystemPermissionRequestedState.value
        set(value) {
            locationSystemPermissionRequestedState.value = value
            store?.putBoolean(LocationSystemPermissionRequestedKey, value)
        }
    var callLogPermissionRequested: Boolean
        get() = callLogPermissionRequestedState.value
        set(value) {
            callLogPermissionRequestedState.value = value
            store?.putBoolean(CallLogPermissionRequestedKey, value)
        }

    fun countryIso(translationMode: Boolean): String {
        return if (translationMode) translationCountryState.value else normalCountryState.value
    }

    fun selectCountry(
        iso: String,
        translationMode: Boolean = translateEnabled,
        syncPeerLanguage: Boolean = true
    ) {
        val normalized = iso.uppercase()
        if (translationMode) {
            translationCountryState.value = normalized
            store?.putString(TranslationCountryKey, normalized)
        } else {
            normalCountryState.value = normalized
            store?.putString(NormalCountryKey, normalized)
        }
        if (syncPeerLanguage) {
            val inferred = inferredLanguageForCountry(normalized)
            otherLanguageState.value = inferred
            store?.putString(OtherLanguageKey, inferred)
        }
    }
}

@Composable
internal fun rememberAssistantDialerPreferenceState(
    prefs: SharedPreferences?
): AssistantDialerPreferenceState {
    val store = remember(prefs) {
        prefs?.let(::SharedPreferencesDialerPreferenceStore)
    }
    val translateEnabledState = rememberSaveable {
        mutableStateOf(store?.getBoolean(TranslateEnabledKey, true) ?: true)
    }
    val promptBeforeCallState = rememberSaveable {
        mutableStateOf(store?.getBoolean(PromptBeforeCallKey, true) ?: true)
    }
    val myLanguageState = rememberSaveable {
        mutableStateOf(store?.getString(MyLanguageKey, "中文") ?: "中文")
    }
    val otherLanguageState = rememberSaveable {
        mutableStateOf(store?.getString(OtherLanguageKey, "英文") ?: "英文")
    }
    val normalCountryState = rememberSaveable {
        mutableStateOf(store?.getString(NormalCountryKey, "CN") ?: "CN")
    }
    val translationCountryState = rememberSaveable {
        mutableStateOf(store?.getString(TranslationCountryKey, "CN") ?: "CN")
    }
    val locationPromptShownState = rememberSaveable {
        mutableStateOf(store?.getBoolean(LocationPromptShownKey, false) ?: false)
    }
    val locationSystemPermissionRequestedState = rememberSaveable {
        mutableStateOf(
            store?.getBoolean(LocationSystemPermissionRequestedKey, false) ?: false
        )
    }
    val callLogPermissionRequestedState = rememberSaveable {
        mutableStateOf(
            store?.getBoolean(CallLogPermissionRequestedKey, false) ?: false
        )
    }
    return remember(
        store,
        translateEnabledState,
        promptBeforeCallState,
        myLanguageState,
        otherLanguageState,
        normalCountryState,
        translationCountryState,
        locationPromptShownState,
        locationSystemPermissionRequestedState,
        callLogPermissionRequestedState
    ) {
        AssistantDialerPreferenceState(
            store = store,
            translateEnabledState = translateEnabledState,
            promptBeforeCallState = promptBeforeCallState,
            myLanguageState = myLanguageState,
            otherLanguageState = otherLanguageState,
            normalCountryState = normalCountryState,
            translationCountryState = translationCountryState,
            locationPromptShownState = locationPromptShownState,
            locationSystemPermissionRequestedState = locationSystemPermissionRequestedState,
            callLogPermissionRequestedState = callLogPermissionRequestedState
        )
    }
}

private const val PromptBeforeCallKey = "dial_prompt_before_translation"
private const val TranslateEnabledKey = "dial_translation_enabled"
private const val MyLanguageKey = "dial_translation_language_mine"
private const val OtherLanguageKey = "dial_translation_language_other"
private const val NormalCountryKey = "dial_country_normal"
private const val TranslationCountryKey = "dial_country_translation"
private const val LocationPromptShownKey = "dial_location_prompt_shown"
private const val LocationSystemPermissionRequestedKey = "dial_location_permission_requested"
private const val CallLogPermissionRequestedKey = "dial_call_log_permission_requested"

private fun inferredLanguageForCountry(iso: String): String = when (iso.uppercase()) {
    "CN" -> "中文"
    "SG" -> "英文"
    "JP" -> "日语"
    else -> "英文"
}
