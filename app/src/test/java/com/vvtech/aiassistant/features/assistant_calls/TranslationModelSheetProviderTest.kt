package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Test

class TranslationModelSheetProviderTest {
    @Test
    fun usesPersistedDoubaoProviderInsteadOfDisplayNameFallback() {
        assertEquals("DOUBAO", translationModelSheetProvider("DOUBAO"))
    }

    @Test
    fun defaultsToQwenOnlyWhenProviderIsMissingOrUnsupported() {
        assertEquals("QWEN_OMNI_PLUS", translationModelSheetProvider(null))
        assertEquals("QWEN_OMNI_PLUS", translationModelSheetProvider("QWEN_OMNI_PLUS"))
        assertEquals("QWEN_OMNI_PLUS", translationModelSheetProvider("QWEN_OMNI_FLASH"))
        assertEquals("QWEN_OMNI_PLUS", translationModelSheetProvider("unknown"))
    }

    @Test
    fun normalizesLegacyAvailableProvidersForTheModelSheet() {
        assertEquals(
            setOf("QWEN_OMNI_PLUS", "DOUBAO"),
            translationModelSheetAvailableProviders(setOf("QWEN_OMNI_FLASH", "DOUBAO"))
        )
    }

    @Test
    fun ignoresUnknownAvailableProvidersInsteadOfMakingQwenAvailable() {
        assertEquals(
            setOf("DOUBAO"),
            translationModelSheetAvailableProviders(setOf("unknown", "DOUBAO"))
        )
    }

    @Test
    fun mapsOverseasProviders() {
        assertEquals("OPENAI", translationModelSheetProvider("GPT_LIVE_TRANSLATE"))
        assertEquals("OPENAI", translationModelSheetProvider("OPENAI"))
        assertEquals("GEMINI", translationModelSheetProvider("GEMINI_LIVE"))
        assertEquals("GEMINI", translationModelSheetProvider("GEMINI"))
    }
}
