package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.model.RealtimeCallProviderItem
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import org.junit.Assert.assertEquals
import org.junit.Test

class RealtimeCallModelCatalogUiMapperTest {

    @Test
    fun mapsServerDisplayContentWithoutProviderRewriting() {
        val response = RealtimeCallProviderResponse(
            activeProvider = "QWEN_OMNI_PLUS",
            activeProviderDisplayName = "服务端 Qwen 名称",
            source = "account-db",
            updatedAt = null,
            providers = listOf(
                RealtimeCallProviderItem(
                    provider = "QWEN_OMNI_PLUS",
                    displayName = "服务端 Qwen 名称",
                    description = "服务端 Qwen 介绍",
                    active = true,
                    configured = true,
                    available = true,
                    statusMessage = "ready"
                ),
                RealtimeCallProviderItem(
                    provider = "FUTURE_MODEL",
                    displayName = "Future Realtime",
                    description = "服务端未来模型介绍",
                    active = false,
                    configured = false,
                    available = false,
                    statusMessage = "coming soon"
                )
            )
        )

        val options = response.toV88VoiceModelOptions()

        assertEquals(listOf("QWEN_OMNI_PLUS", "FUTURE_MODEL"), options.map { it.id })
        assertEquals(listOf("QwenOmniPlus", "Future Realtime"), options.map { it.title })
        assertEquals(listOf("服务端 Qwen 介绍", "服务端未来模型介绍"), options.map { it.subtitle })
        assertEquals(listOf(true, false), options.map { it.enabled })
    }

    @Test
    fun mapsNullDescriptionToEmptySubtitle() {
        val response = RealtimeCallProviderResponse(
            activeProvider = "QWEN_OMNI_PLUS",
            activeProviderDisplayName = "Qwen",
            source = "account-db",
            updatedAt = null,
            providers = listOf(
                RealtimeCallProviderItem(
                    provider = "QWEN_OMNI_PLUS",
                    displayName = "Qwen",
                    description = null,
                    active = true,
                    configured = true,
                    available = true,
                    statusMessage = "ready"
                )
            )
        )

        assertEquals("", response.toV88VoiceModelOptions().single().subtitle)
    }

    @Test
    fun mapsLegacyQwenProviderToOmniPlusId() {
        val response = RealtimeCallProviderResponse(
            activeProvider = "QWEN_OMNI_FLASH",
            activeProviderDisplayName = "QwenOmniPlus",
            source = "account-db",
            updatedAt = null,
            providers = listOf(provider("QWEN_OMNI_FLASH", "QwenOmniPlus"))
        )

        assertEquals(
            listOf("QWEN_OMNI_PLUS"),
            resolveV88VoiceModelOptions(response).map { it.id }
        )
        assertEquals("QWEN_OMNI_PLUS", normalizeAiCallModelId(response.activeProvider))
    }

    @Test
    fun fallsBackToExistingOptionsOnlyWhenServerCatalogIsMissing() {
        val options = resolveV88VoiceModelOptions(response = null)

        assertEquals(
            listOf("QWEN_OMNI_PLUS", "DOUBAO", "DOUBAO_SEEDUPLEX_3_0"),
            options.map { it.id }
        )
        assertEquals(listOf(false, false, false), options.map { it.enabled })
    }

    @Test
    fun sharedHomeAndTaskSheetKeepsOnlyQwenAndDoubao() {
        val response = RealtimeCallProviderResponse(
            activeProvider = "QWEN_OMNI_PLUS",
            activeProviderDisplayName = "QwenOmniPlus",
            source = "account-db",
            updatedAt = null,
            providers = listOf(
                provider("QWEN_OMNI_PLUS", "QwenOmniPlus"),
                provider("DOUBAO", "Seeduplex"),
                provider("DOUBAO_SEEDUPLEX_3_0", "豆包实时语音 3.0"),
                provider("GPT", "GPT Realtime2.0"),
                provider("GEMINI", "Gemini Live")
            )
        )

        assertEquals(
            listOf("QWEN_OMNI_PLUS", "DOUBAO", "DOUBAO_SEEDUPLEX_3_0"),
            resolveV88VoiceModelOptions(response).map { it.id }
        )
    }

    private fun provider(id: String, name: String) = RealtimeCallProviderItem(
        provider = id,
        displayName = name,
        description = "$name 介绍",
        active = id == "QWEN_OMNI_PLUS",
        configured = true,
        available = true,
        statusMessage = "ready"
    )
}
