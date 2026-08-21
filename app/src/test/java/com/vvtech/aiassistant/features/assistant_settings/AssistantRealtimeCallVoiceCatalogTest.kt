package com.vvtech.aiassistant.features.assistant_settings

import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse
import com.vvtech.aiassistant.model.RealtimeCallVoiceItem
import com.vvtech.aiassistant.model.UpdateRealtimeCallVoiceRequest
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRealtimeCallVoiceCatalogTest {
    @Test
    fun qwenVoiceCatalogKeepsAndreFirstAndPackagesFinalPreviews() {
        val voices = listOf(
            voice("Katerina"),
            voice("Andre"),
            voice("Ethan"),
            voice("andre"),
            voice("Harvey")
        )

        assertEquals(
            listOf("Andre", "Ethan", "Katerina"),
            visibleRealtimeCallVoices("QWEN_OMNI_PLUS", voices).map { it.voice }
        )
        listOf("andre", "ethan", "katerina").forEach { voice ->
            assertTrue(File("src/main/res/raw/$voice.wav").isFile)
        }
        assertFalse(File("src/main/res/raw/harvey.wav").exists())
    }

    @Test
    fun doubaoVoiceCatalogOnlyExposesClearMale() {
        val clear = voice("zh_male_xiaotian_jupiter_bigtts", "旧清朗名称")
        val steady = voice("S_1C6XHhfZ1", "稳重男声")
        val visible = visibleRealtimeCallVoices("DOUBAO", listOf(steady, clear))

        assertEquals(listOf(clear.voice), visible.map { it.voice })
        assertEquals("Seeduplex Clear Male", realtimeCallVoiceDisplayName(clear.voice, clear.displayName))
        assertEquals("Seeduplex clear male.", buildVoiceSubtitle(clear))
        assertTrue(File("src/main/res/raw/doubao_clear_male.wav").isFile)
    }

    @Test
    fun realtimeVoiceContractDefaultsToAiAndSupportsCloneMode() {
        val response = RealtimeCallVoiceResponse(
            activeVoice = "Andre",
            activeVoiceDisplayName = "Andre",
            defaultVoice = "Andre",
            source = "default",
            updatedAt = null,
            voices = emptyList()
        )
        val request = UpdateRealtimeCallVoiceRequest(voice = null, selectionMode = "CLONE")

        assertEquals("AI", response.selectionMode)
        assertEquals("CLONE", request.selectionMode)
        assertNull(request.voice)
    }

    @Test
    fun voiceCatalogDescriptionUsesCurrentModelDisplayName() {
        assertEquals(
            "当前语音大模型 QwenOmniPlus 支持以下音色",
            realtimeCallVoiceCatalogDescription("QWEN_OMNI_PLUS")
        )
        assertEquals(
            "当前语音大模型 Seeduplex 支持以下音色",
            realtimeCallVoiceCatalogDescription("DOUBAO")
        )
    }

    @Test
    fun voiceCatalogDescriptionUsesEnglishSettingsCopy() {
        assertEquals(
            "Current voice model QwenOmniPlus supports these voices.",
            realtimeCallVoiceCatalogDescription("QWEN_OMNI_PLUS", AppLanguage.English)
        )
    }

    @Test
    fun settingsUsesOneEntrySharedModelCatalogAndMergedCloneSection() {
        val settingsHome = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalSettingsHomePage.kt"
        )
        val providerPage = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalRealtimeSettingsPages.kt"
        )
        val cloneSection = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_settings/AssistantRealtimeCallCloneVoiceSection.kt"
        )
        val voiceSettingsPage = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_settings/AssistantRealtimeCallVoiceSettingsPage.kt"
        )
        val settingsPageHost = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantTaskSettingsPageHost.kt"
        )

        assertTrue(settingsHome.contains("R.string.settings_call_models_voices_title"))
        assertFalse(settingsHome.contains("title = \"克隆声音\""))
        assertTrue(providerPage.contains("providerResponse?.toV88VoiceModelOptions()"))
        assertFalse(providerPage.contains("statusMessage.isNullOrBlank()"))
        assertTrue(providerPage.contains("if (model.enabled) Color(0xFF111827) else Color(0xFF9B9BA1)"))
        assertTrue(providerPage.contains("R.string.call_models_voice_clone_entry"))
        assertFalse(providerPage.contains("text = \"设置通话语音\""))
        assertFalse(providerPage.contains("AI音色、克隆声音"))
        assertTrue(voiceSettingsPage.contains("R.string.call_voice_clone_not_supported"))
        assertFalse(voiceSettingsPage.contains("\"刷新音色\""))
        assertFalse(voiceSettingsPage.contains("val onRefresh: () -> Unit"))
        assertFalse(settingsPageHost.contains("onRefresh = { onRefreshRealtimeCallVoice(true) }"))
        assertTrue(cloneSection.contains("VoiceCloneGroupCard"))
        assertTrue(cloneSection.contains("selectionMode.equals(\"CLONE\""))
    }

    private fun sourceFile(path: String): String = File(path).readText(Charsets.UTF_8)

    private fun voice(voice: String, displayName: String = voice) = RealtimeCallVoiceItem(
        voice = voice,
        displayName = displayName,
        description = "",
        selected = false,
        defaultVoice = false
    )
}
