package com.vvtech.aiassistant.features.translation_call.ui

import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import org.junit.Assert.assertEquals
import org.junit.Test

class TranslationProviderUiCatalogTest {
    @Test
    fun `domestic translation names match the dialer catalog`() {
        assertEquals(
            listOf("Qwen LT Flash", "Doubao AST LT"),
            TranslationProviderUiCatalog.domesticOptions.map { it.displayName }
        )
        assertEquals(
            listOf("QWEN_OMNI_PLUS", "DOUBAO"),
            TranslationProviderUiCatalog.domesticOptions.map { it.id }
        )
    }

    @Test
    fun `initialization and dialer aliases resolve to the same providers`() {
        assertEquals(
            TranslationRealtimeProvider.Qwen,
            TranslationProviderUiCatalog.option("qwen3.5")?.provider
        )
        assertEquals(
            TranslationRealtimeProvider.Doubao,
            TranslationProviderUiCatalog.option("Seeduplex")?.provider
        )
        assertEquals(
            "OPENAI",
            TranslationProviderUiCatalog.normalizeProviderId("GPT_LIVE_TRANSLATE")
        )
        assertEquals(
            "GEMINI",
            TranslationProviderUiCatalog.normalizeProviderId("GEMINI_LIVE")
        )
        assertEquals(
            "QWEN_OMNI_PLUS",
            TranslationProviderUiCatalog.normalizeProviderId("QWEN_OMNI_FLASH")
        )
    }

    @Test
    fun `unknown provider falls back to the persisted domestic default`() {
        assertEquals(
            TranslationProviderUiCatalog.QwenId,
            TranslationProviderUiCatalog.normalizeProviderId("unknown")
        )
        assertEquals(
            "Qwen LT Flash",
            TranslationProviderUiCatalog.displayName(null)
        )
    }

    @Test
    fun `v63 translation catalog keeps all four model product names`() {
        assertEquals(
            listOf("Qwen LT Flash", "Doubao AST LT", "GPT RT Translate", "Gemini Live"),
            TranslationProviderUiCatalog.allOptions.map { it.displayName }
        )
    }
}
