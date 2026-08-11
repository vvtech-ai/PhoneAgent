package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceModelDefaultsTest {

    @Test
    fun defaultRealtimeCallVoiceModelShouldBeQwen() {
        val defaultOption = defaultV88VoiceModelOption()

        assertEquals("QWEN_OMNI_PLUS", defaultOption.id)
        assertEquals("QwenOmniPlus", defaultOption.title)
    }

    @Test
    fun realtimeCallVoiceModelOrderShouldBeFixed() {
        assertEquals(
            listOf("QWEN_OMNI_PLUS", "DOUBAO", "DOUBAO_SEEDUPLEX_3_0", "GPT"),
            V88VoiceModelOptions.map { it.id }
        )
        assertEquals(
            listOf("QwenOmniPlus", "Seeduplex", "豆包实时语音 3.0", "GPT Realtime2.0"),
            V88VoiceModelOptions.map { it.title }
        )
        assertEquals(
            listOf(
                "阿里巴巴 · 全双工语音对话引擎",
                "字节跳动 · 端到端双工语音模型",
                "字节跳动 · Seeduplex 全双工语音模型",
                "GPT 实时语音模型"
            ),
            V88VoiceModelOptions.map { it.subtitle }
        )
        assertEquals(listOf(true, true, true, false), V88VoiceModelOptions.map { it.enabled })
    }

    @Test
    fun providerIdsShouldRoundTripToTheHomeSheetIds() {
        assertEquals("DOUBAO", "DOUBAO".toV88VoiceModelId())
        assertEquals("DOUBAO_SEEDUPLEX_3_0", "DOUBAO_SEEDUPLEX_3_0".toV88VoiceModelId())
        assertEquals("QWEN_OMNI_PLUS", "QWEN_OMNI_FLASH".toV88VoiceModelId())
        assertEquals("QWEN_OMNI_PLUS", "QWEN_OMNI_PLUS".toV88VoiceModelId())
        assertEquals("DOUBAO", "DOUBAO".toRealtimeCallProviderValue())
        assertEquals("DOUBAO_SEEDUPLEX_3_0", "DOUBAO_SEEDUPLEX_3_0".toRealtimeCallProviderValue())
        assertEquals("QWEN_OMNI_PLUS", "QWEN_OMNI_FLASH".toRealtimeCallProviderValue())
        assertEquals("QWEN_OMNI_PLUS", "QWEN_OMNI_PLUS".toRealtimeCallProviderValue())
    }

    @Test
    fun shouldKeepRealtimeProviderOnStartup() {
        assertEquals(false, shouldAutoSwitchRealtimeProviderOnStartup("DOUBAO", false))
        assertEquals(false, shouldAutoSwitchRealtimeProviderOnStartup("QWEN_OMNI_PLUS", false))
        assertEquals(false, shouldAutoSwitchRealtimeProviderOnStartup("DOUBAO", true))
    }

    @Test
    fun mergedVoiceAndClonePagesReturnToTheModelVoiceFlow() {
        assertEquals(
            FinalPage.RealtimeProviderSettings,
            finalBackTargetPage(FinalPage.RealtimeCallVoiceSettings, false, FinalPage.Calls.name)
        )
        assertEquals(
            FinalPage.RealtimeCallVoiceSettings,
            finalBackTargetPage(FinalPage.VoiceCloneSettings, false, FinalPage.Calls.name)
        )
    }
}
