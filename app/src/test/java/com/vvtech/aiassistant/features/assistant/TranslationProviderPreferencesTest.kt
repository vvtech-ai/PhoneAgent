package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.TranslationLanguageMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TranslationProviderPreferencesTest {

    @Test
    fun qwenTranslationRequestUsesManualLanguagesAndPreferredVoice() {
        val request = buildTranslationStartRequest(
            userId = "user-1",
            phoneNumber = "13800138000",
            displayName = "Front Desk",
            translationProvider = "QWEN_OMNI_PLUS",
            qwenVoicePreference = "Nofish",
            languageSettings = TranslationProviderLanguageSettings(
                callerLanguage = "ja",
                calleeLanguage = "en"
            )
        )

        assertEquals(TranslationLanguageMode.MANUAL, request.languageMode)
        assertEquals("ja", request.callerPreferredLanguage)
        assertEquals("en", request.calleePreferredLanguage)
        assertEquals("Nofish", request.preferredVoice)
    }

    @Test
    fun legacyQwenProviderUsesTheSameManualTranslationSettings() {
        val request = buildTranslationStartRequest(
            userId = "user-1",
            phoneNumber = "13800138000",
            displayName = null,
            translationProvider = "QWEN_OMNI_FLASH",
            qwenVoicePreference = "Nofish",
            languageSettings = TranslationProviderLanguageSettings(
                callerLanguage = "ja",
                calleeLanguage = "en"
            )
        )

        assertEquals(TranslationLanguageMode.MANUAL, request.languageMode)
        assertEquals("ja", request.callerPreferredLanguage)
        assertEquals("en", request.calleePreferredLanguage)
    }

    @Test
    fun nonQwenTranslationRequestKeepsAutoModeWithoutManualLanguages() {
        val request = buildTranslationStartRequest(
            userId = "user-1",
            phoneNumber = "13800138000",
            displayName = null,
            translationProvider = "DOUBAO",
            qwenVoicePreference = "Nofish",
            languageSettings = TranslationProviderLanguageSettings(
                callerLanguage = "zh",
                calleeLanguage = "en"
            )
        )

        assertEquals(TranslationLanguageMode.AUTO, request.languageMode)
        assertNull(request.callerPreferredLanguage)
        assertNull(request.calleePreferredLanguage)
        assertNull(request.preferredVoice)
    }

    @Test
    fun missingTranslationProviderDoesNotBecomeQwenManualMode() {
        val request = buildTranslationStartRequest(
            userId = "user-1",
            phoneNumber = "13800138000",
            displayName = null,
            translationProvider = null,
            qwenVoicePreference = "Nofish",
            languageSettings = TranslationProviderLanguageSettings()
        )

        assertEquals(TranslationLanguageMode.AUTO, request.languageMode)
        assertNull(request.callerPreferredLanguage)
        assertNull(request.calleePreferredLanguage)
        assertNull(request.preferredVoice)
    }

    @Test
    fun invalidLanguagePreferencesFallBackToChineseAndEnglish() {
        val settings = sanitizeTranslationProviderLanguageSettings(
            callerLanguage = "xx",
            calleeLanguage = "yy"
        )

        assertEquals("zh", settings.callerLanguage)
        assertEquals("en", settings.calleeLanguage)
    }

    @Test
    fun languageLabelsUseHumanReadableText() {
        assertEquals("中文", translationLanguageLabel("zh"))
        assertEquals("English", translationLanguageLabel("en"))
        assertEquals("日本語", translationLanguageLabel("ja"))
    }
}
