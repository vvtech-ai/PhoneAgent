package com.vvtech.aiassistant.features.assistant_calls

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.logging.AppFileLogger

internal class AssistantDialerStateHolder(
    private val preferences: AssistantDialerPreferenceState = AssistantDialerPreferenceState(),
    private val dialInputState: MutableState<String> = mutableStateOf(""),
    private val lastDialedNumberState: MutableState<String> = mutableStateOf(""),
    private val targetDisplayNameState: MutableState<String> = mutableStateOf(""),
    private val countrySelectionLogger: (String, String, String, String) -> Unit =
        { _, _, _, _ -> }
) {
    var dialInput: String by dialInputState
    var lastDialedNumber: String by lastDialedNumberState
    var targetDisplayName: String by targetDisplayNameState
    var translateEnabled: Boolean
        get() = preferences.translateEnabled
        set(value) { preferences.translateEnabled = value }
    var promptBeforeTranslationCall: Boolean
        get() = preferences.promptBeforeCall
        set(value) { preferences.promptBeforeCall = value }
    var myLanguage: String
        get() = preferences.myLanguage
        set(value) { preferences.myLanguage = value }
    var otherLanguage: String
        get() = preferences.otherLanguage
        set(value) { preferences.otherLanguage = value }
    val selectedCountryIso: String
        get() = preferences.selectedCountryIso
    var locationPromptShown: Boolean
        get() = preferences.locationPromptShown
        set(value) { preferences.locationPromptShown = value }
    var locationSystemPermissionRequested: Boolean
        get() = preferences.locationSystemPermissionRequested
        set(value) { preferences.locationSystemPermissionRequested = value }
    var callLogPermissionRequested: Boolean
        get() = preferences.callLogPermissionRequested
        set(value) { preferences.callLogPermissionRequested = value }

    fun appendDigit(digit: String) {
        val canAppend = digit.none(Char::isDigit) ||
            dialInput.count(Char::isDigit) < MaxDialNationalDigits
        if (canAppend) {
            targetDisplayName = ""
            dialInput += digit
        }
    }

    fun deleteDigit() {
        targetDisplayName = ""
        dialInput = dialInput.dropLast(1)
    }

    fun fullDialNumber(): String {
        if (dialInput.none(Char::isDigit)) return ""
        return "${dialCountryByIso(selectedCountryIso).dialCode}$dialInput"
    }

    fun prepareContactNumber(
        raw: String,
        displayName: String = "",
        translationMode: Boolean = translateEnabled
    ): ContactDialNumberResult {
        val result = parseContactDialNumber(raw, preferences.countryIso(translationMode))
        if (result is ContactDialNumberResult.Supported) {
            preferences.selectCountry(
                result.countryIso,
                translationMode,
                syncPeerLanguage = false
            )
            dialInput = result.nationalNumber
            lastDialedNumber = result.nationalNumber
            targetDisplayName = displayName.trim()
        }
        return result
    }

    fun restoreHistoryTarget(target: DialTargetSelection): ContactDialNumberResult {
        val translationMode = translateEnabled
        val result = prepareContactNumber(target.phoneNumber, target.displayName, translationMode)
        if (result is ContactDialNumberResult.Supported) {
            target.countryIso.takeIf(String::isNotBlank)?.let {
                preferences.selectCountry(
                    it,
                    translationMode,
                    syncPeerLanguage = false
                )
            }
            dialTranslationLanguageLabel(target.callerLanguageCode)?.let { myLanguage = it }
            dialTranslationLanguageLabel(target.calleeLanguageCode)?.let { otherLanguage = it }
        }
        return result
    }

    fun selectCountry(iso: String, translationMode: Boolean = translateEnabled) {
        val previousCountryIso = preferences.countryIso(translationMode)
        val previousLanguage = otherLanguage
        preferences.selectCountry(iso, translationMode)
        countrySelectionLogger(
            previousCountryIso,
            preferences.countryIso(translationMode),
            previousLanguage,
            otherLanguage
        )
    }

    fun clearNumbers() {
        dialInput = ""
        lastDialedNumber = ""
        targetDisplayName = ""
    }
}

@Composable
internal fun rememberAssistantDialerStateHolder(
    prefs: SharedPreferences?
): AssistantDialerStateHolder {
    val preferences = rememberAssistantDialerPreferenceState(prefs)
    val dialInputState = rememberSaveable { mutableStateOf("") }
    val lastDialedNumberState = rememberSaveable { mutableStateOf("") }
    val targetDisplayNameState = rememberSaveable { mutableStateOf("") }
    return remember(preferences, dialInputState, lastDialedNumberState, targetDisplayNameState) {
        AssistantDialerStateHolder(
            preferences = preferences,
            dialInputState = dialInputState,
            lastDialedNumberState = lastDialedNumberState,
            targetDisplayNameState = targetDisplayNameState,
            countrySelectionLogger = ::logDialCountrySelection
        )
    }
}

private fun logDialCountrySelection(
    previousCountryIso: String,
    selectedCountryIso: String,
    previousLanguage: String,
    selectedLanguage: String
) {
    AppFileLogger.i(
        "DIAL_COUNTRY_SYNC",
        "event=country_selected " +
            "stateBefore=$previousCountryIso " +
            "stateAfter=$selectedCountryIso " +
            "peerLanguageBefore=$previousLanguage " +
            "peerLanguageAfter=$selectedLanguage " +
            "reason=user_country_selection"
    )
}
