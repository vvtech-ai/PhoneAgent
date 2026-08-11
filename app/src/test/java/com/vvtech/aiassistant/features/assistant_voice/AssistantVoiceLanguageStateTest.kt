package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoiceLanguageStateTest {
    @Test
    fun defaultsToChineseWhenInitialCodeIsMissingOrInvalid() {
        val missing = AssistantVoiceLanguageState(initialCode = null)
        val invalid = AssistantVoiceLanguageState(initialCode = "not-a-language")

        assertEquals(DefaultVoiceLanguageCode, missing.code)
        assertEquals(VoiceLanguage.Chinese, missing.language)
        assertEquals(DefaultVoiceLanguageCode, invalid.code)
        assertEquals(VoiceLanguage.Chinese, invalid.language)
    }

    @Test
    fun normalizesAndPersistsChangedLanguage() {
        val persisted = mutableListOf<String>()
        val state = AssistantVoiceLanguageState(
            initialCode = DefaultVoiceLanguageCode,
            persistCode = persisted::add
        )

        assertTrue(state.set("en"))
        assertEquals(VoiceLanguage.English.code, state.code)
        assertEquals(VoiceLanguage.English, state.language)
        assertEquals(listOf(VoiceLanguage.English.code), persisted)

        assertTrue(state.set("jp"))
        assertEquals(VoiceLanguage.Japanese.code, state.code)
        assertEquals(VoiceLanguage.Japanese, state.language)
        assertEquals(listOf(VoiceLanguage.English.code, VoiceLanguage.Japanese.code), persisted)
    }

    @Test
    fun settingSameNormalizedLanguageIsIdempotent() {
        val persisted = mutableListOf<String>()
        val state = AssistantVoiceLanguageState(
            initialCode = "en-US",
            persistCode = persisted::add
        )

        assertFalse(state.set("en"))
        assertEquals(VoiceLanguage.English.code, state.code)
        assertTrue(persisted.isEmpty())
    }

    @Test
    fun assistantViewModelDoesNotPersistVoiceLanguageDirectly() {
        val viewModelFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        )
        val stateFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/AssistantVoiceLanguageState.kt"
        )
        val viewModel = viewModelFile.readText(Charsets.UTF_8)
        val state = stateFile.readText(Charsets.UTF_8)

        assertTrue(stateFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(viewModel.contains("private val voiceLanguageState = AssistantVoiceLanguageState(appContext)"))
        assertTrue(viewModel.contains("get() = voiceLanguageState.code"))
        assertTrue(viewModel.contains("voiceLanguageState.set(languageCode)"))
        assertTrue(viewModel.contains("voiceLanguageState.language"))
        assertFalse(viewModel.contains("voiceLanguagePrefs"))
        assertFalse(viewModel.contains("getSharedPreferences(VoiceLanguagePrefsName"))
        assertFalse(viewModel.contains("putString(VoiceLanguageCodeKey"))
        assertTrue(state.contains("getSharedPreferences(VoiceLanguagePrefsName"))
        assertTrue(state.contains("putString(VoiceLanguageCodeKey"))
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
