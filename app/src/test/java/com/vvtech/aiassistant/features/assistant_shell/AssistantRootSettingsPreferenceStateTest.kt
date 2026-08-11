package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalDeveloperModeEnabledKey
import com.vvtech.aiassistant.features.assistant.FinalTranslationQwenCalleeLanguageKey
import com.vvtech.aiassistant.features.assistant.FinalTranslationQwenCallerLanguageKey
import com.vvtech.aiassistant.features.assistant.FinalTranslationQwenVoiceKey
import com.vvtech.aiassistant.features.assistant.TranslationProviderLanguageSettings
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_settings.DefaultDomesticSipAccountId
import com.vvtech.aiassistant.features.assistant_settings.DefaultInternationalSipAccountId
import com.vvtech.aiassistant.features.assistant_settings.DomesticSipAccountPreferenceKey
import com.vvtech.aiassistant.features.assistant_settings.InternationalSipAccountPreferenceKey
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootSettingsPreferenceStateTest {
    @Test
    fun enableDeveloperModeWritesPreferenceOnlyOnFirstEnable() {
        val store = MemorySettingsPreferenceStore()
        val state = state(store)

        assertFalse(state.developerModeEnabled)

        assertTrue(state.enableDeveloperMode())
        assertTrue(state.developerModeEnabled)
        assertEquals(true, store.booleans[FinalDeveloperModeEnabledKey])
        assertEquals(1, store.booleanWriteCount)

        assertFalse(state.enableDeveloperMode())
        assertEquals(1, store.booleanWriteCount)
    }

    @Test
    fun updateTranslationPreferencesSanitizesAndPersistsExistingKeys() {
        val store = MemorySettingsPreferenceStore()
        val state = state(store)

        state.updateTranslationQwenVoicePreference("invalid")
        state.updateTranslationQwenLanguageSettings(
            TranslationProviderLanguageSettings(
                callerLanguage = "ja",
                calleeLanguage = "de"
            )
        )

        assertEquals("Nofish", state.translationQwenVoicePreference)
        assertEquals("Nofish", store.strings[FinalTranslationQwenVoiceKey])
        assertEquals(
            TranslationProviderLanguageSettings(callerLanguage = "ja", calleeLanguage = "de"),
            state.translationQwenLanguageSettings
        )
        assertEquals("ja", store.strings[FinalTranslationQwenCallerLanguageKey])
        assertEquals("de", store.strings[FinalTranslationQwenCalleeLanguageKey])
    }

    @Test
    fun developerDataModeAndVoiceLanguageStayInSingleStateHolder() {
        val state = state(
            voiceLanguageCode = "en-US",
            pureVoiceMode = true
        )

        state.applyDeveloperDataMode(DeveloperDataMode.Filled)

        assertEquals(DeveloperDataMode.Filled.name, state.developerDataModeName)
        assertTrue(state.pureVoiceMode)
        assertEquals(VoiceLanguage.English, state.voiceLanguage)
    }

    @Test
    fun sipAccountPreferencesValidatePersistAndKeepSelectionsIndependent() {
        val store = MemorySettingsPreferenceStore()
        val state = state(store)

        assertEquals(DefaultDomesticSipAccountId, state.selectedDomesticSipAccountId)
        assertEquals(DefaultInternationalSipAccountId, state.selectedInternationalSipAccountId)

        state.updateDomesticSipAccountId("21311780")
        state.updateInternationalSipAccountId("1008")

        assertEquals("21311780", state.selectedDomesticSipAccountId)
        assertEquals("1008", state.selectedInternationalSipAccountId)
        assertEquals("21311780", store.strings[DomesticSipAccountPreferenceKey])
        assertEquals("1008", store.strings[InternationalSipAccountPreferenceKey])

        state.updateDomesticSipAccountId("unknown")
        state.updateInternationalSipAccountId("unknown")

        assertEquals(DefaultDomesticSipAccountId, state.selectedDomesticSipAccountId)
        assertEquals(DefaultInternationalSipAccountId, state.selectedInternationalSipAccountId)
    }

    @Test
    fun assistantRootScreenDelegatesSettingsPreferenceState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootSettingsPreferenceState.kt")
                .readText(Charsets.UTF_8)
        val pageHostSecondaryFactory =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostSecondaryArgsFactory.kt"
            ).readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val rootSettingsState = rootRuntimeGraph.state.rootSettings"))
        assertTrue(runtimeGraph.contains("rememberAssistantRootSettingsPreferenceState(prefs)"))
        assertFalse(root.contains("onApplyDeveloperDataMode = rootSettingsState::applyDeveloperDataMode"))
        assertTrue(actionGraph.contains("onApplyDeveloperDataMode = state.rootSettings::applyDeveloperDataMode"))
        assertFalse(root.contains("rootSettingsState.enableDeveloperMode()"))
        assertTrue(actionGraph.contains("state.rootSettings.enableDeveloperMode()"))
        assertTrue(root.contains("settings = rootSettingsState"))
        assertTrue(pageHostSecondaryFactory.contains("state.settings::updateTranslationQwenVoicePreference"))
        assertTrue(pageHostSecondaryFactory.contains("state.settings::updateTranslationQwenLanguageSettings"))
        assertFalse(root.contains("mutableStateListOf<FinalTaskRecord>()"))
        assertFalse(root.contains("taskRecords.clear()"))
        assertFalse(root.contains("putBoolean(FinalDeveloperModeEnabledKey"))
        assertFalse(root.contains("TranslationProviderLanguageSettingsSaver"))
        assertFalse(root.contains("sanitizeTranslationQwenVoice(prefs"))

        assertTrue(holder.contains("FinalDeveloperModeEnabledKey"))
        assertTrue(holder.contains("FinalTranslationQwenVoiceKey"))
        assertTrue(holder.contains("FinalTranslationQwenCallerLanguageKey"))
        assertTrue(holder.contains("FinalTranslationQwenCalleeLanguageKey"))
        assertTrue(holder.contains("FinalDefaultPureVoiceMode"))
    }

    private fun state(
        store: MemorySettingsPreferenceStore = MemorySettingsPreferenceStore(),
        developerModeEnabled: Boolean = false,
        developerDataModeName: String = DeveloperDataMode.Empty.name,
        translationQwenVoicePreference: String = "Nofish",
        translationQwenLanguageSettings: TranslationProviderLanguageSettings = TranslationProviderLanguageSettings(),
        pureVoiceMode: Boolean = true,
        voiceLanguageCode: String = "zh-CN",
        selectedDomesticSipAccountId: String = DefaultDomesticSipAccountId,
        selectedInternationalSipAccountId: String = DefaultInternationalSipAccountId
    ): AssistantRootSettingsPreferenceState {
        return AssistantRootSettingsPreferenceState(
            store = store,
            developerModeEnabledState = mutableStateOf(developerModeEnabled),
            developerDataModeNameState = mutableStateOf(developerDataModeName),
            translationQwenVoicePreferenceState = mutableStateOf(translationQwenVoicePreference),
            translationQwenLanguageSettingsState = mutableStateOf(translationQwenLanguageSettings),
            pureVoiceModeState = mutableStateOf(pureVoiceMode),
            voiceLanguageCodeState = mutableStateOf(voiceLanguageCode),
            selectedDomesticSipAccountIdState = mutableStateOf(selectedDomesticSipAccountId),
            selectedInternationalSipAccountIdState = mutableStateOf(selectedInternationalSipAccountId)
        )
    }

    private class MemorySettingsPreferenceStore : AssistantRootSettingsPreferenceStore {
        val booleans = mutableMapOf<String, Boolean>()
        val strings = mutableMapOf<String, String>()
        var booleanWriteCount = 0

        override fun getBoolean(key: String, defaultValue: Boolean): Boolean =
            booleans[key] ?: defaultValue

        override fun putBoolean(key: String, value: Boolean) {
            booleans[key] = value
            booleanWriteCount += 1
        }

        override fun getString(key: String, defaultValue: String?): String? =
            strings[key] ?: defaultValue

        override fun putString(key: String, value: String) {
            strings[key] = value
        }
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
