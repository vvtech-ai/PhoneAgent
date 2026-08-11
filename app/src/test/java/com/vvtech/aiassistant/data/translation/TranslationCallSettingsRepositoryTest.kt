package com.vvtech.aiassistant.data.translation

import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsPolicy
import com.vvtech.aiassistant.features.translation_call.model.TranslationServiceEndpointResolver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallSettingsRepositoryTest {
    @Test
    fun `invalid persisted values fall back to regional defaults`() {
        val repository = DefaultTranslationCallSettingsRepository(
            MemoryStore(
                mutableMapOf(
                    "translation_domestic_provider" to "openai",
                    "translation_overseas_provider" to "qwen",
                    "translation_service_region" to "moon"
                )
            )
        )

        assertEquals(TranslationRealtimeProvider.Qwen, repository.state.value.domesticProvider)
        assertEquals(TranslationRealtimeProvider.Gemini, repository.state.value.overseasProvider)
        assertEquals(TranslationServiceRegion.Default, repository.state.value.serviceRegion)
    }

    @Test
    fun `domestic and overseas selections persist independently`() {
        val store = MemoryStore()
        val repository = DefaultTranslationCallSettingsRepository(store)

        repository.selectDomesticProvider(TranslationRealtimeProvider.Doubao)
        repository.selectOverseasProvider(TranslationRealtimeProvider.OpenAi)
        repository.selectServiceRegion(TranslationServiceRegion.Japan)

        val restored = DefaultTranslationCallSettingsRepository(store).state.value
        assertEquals(TranslationRealtimeProvider.Doubao, restored.domesticProvider)
        assertEquals(TranslationRealtimeProvider.OpenAi, restored.overseasProvider)
        assertEquals(TranslationServiceRegion.Japan, restored.serviceRegion)
    }

    @Test
    fun `original audio defaults off and persists when enabled`() {
        val store = MemoryStore()
        val repository = DefaultTranslationCallSettingsRepository(store)

        assertFalse(repository.state.value.playOriginalAudio)
        repository.setPlayOriginalAudio(true)

        assertTrue(DefaultTranslationCallSettingsRepository(store).state.value.playOriginalAudio)
    }

    @Test
    fun `original audio levels use service defaults and persist independently`() {
        val store = MemoryStore()
        val repository = DefaultTranslationCallSettingsRepository(store)

        assertEquals(50, repository.state.value.originalAudioGainPercent)
        assertEquals(100, repository.state.value.originalAudioVolumePercent)
        repository.setOriginalAudioGainPercent(40)
        repository.setOriginalAudioVolumePercent(60)
        repository.setPlayOriginalAudio(false)

        val restored = DefaultTranslationCallSettingsRepository(store).state.value
        assertEquals(40, restored.originalAudioGainPercent)
        assertEquals(60, restored.originalAudioVolumePercent)
    }

    @Test
    fun `original audio gain clamps and snaps invalid values`() {
        assertEquals(
            0,
            DefaultTranslationCallSettingsRepository(
                MemoryStore(ints = mutableMapOf("translation_original_audio_gain_percent" to -20))
            ).state.value.originalAudioGainPercent
        )
        assertEquals(
            50,
            DefaultTranslationCallSettingsRepository(
                MemoryStore(ints = mutableMapOf("translation_original_audio_gain_percent" to 120))
            ).state.value.originalAudioGainPercent
        )
        assertEquals(
            50,
            DefaultTranslationCallSettingsRepository(
                MemoryStore(ints = mutableMapOf("translation_original_audio_gain_percent" to 76))
            ).state.value.originalAudioGainPercent
        )
    }

    @Test
    fun `pure original audio volume clamps and snaps invalid values`() {
        assertEquals(
            0,
            DefaultTranslationCallSettingsRepository(
                MemoryStore(ints = mutableMapOf("translation_original_audio_volume_percent" to -20))
            ).state.value.originalAudioVolumePercent
        )
        assertEquals(
            100,
            DefaultTranslationCallSettingsRepository(
                MemoryStore(ints = mutableMapOf("translation_original_audio_volume_percent" to 120))
            ).state.value.originalAudioVolumePercent
        )
        assertEquals(
            80,
            DefaultTranslationCallSettingsRepository(
                MemoryStore(ints = mutableMapOf("translation_original_audio_volume_percent" to 76))
            ).state.value.originalAudioVolumePercent
        )
    }

    @Test
    fun `china hides service region and shows sip`() {
        val visibility = TranslationCallSettingsPolicy.visibility(resolved("CN"))

        assertTrue(visibility.showDomesticProvider)
        assertTrue(visibility.showSipAccounts)
        assertFalse(visibility.showOverseasProvider)
        assertFalse(visibility.showServiceRegion)
    }

    @Test
    fun `overseas hides sip and shows service region`() {
        val visibility = TranslationCallSettingsPolicy.visibility(resolved("US"))

        assertFalse(visibility.showDomesticProvider)
        assertFalse(visibility.showSipAccounts)
        assertTrue(visibility.showOverseasProvider)
        assertTrue(visibility.showServiceRegion)
    }

    @Test
    fun `unknown location hides all regional settings`() {
        val visibility = TranslationCallSettingsPolicy.visibility(
            TranslationRegionState.Unavailable("定位失败")
        )

        assertFalse(visibility.showDomesticProvider)
        assertFalse(visibility.showOverseasProvider)
        assertFalse(visibility.showSipAccounts)
        assertFalse(visibility.showServiceRegion)
        assertEquals("定位失败", visibility.locationMessage)
    }

    @Test
    fun `endpoint resolver trims urls and falls back to default`() {
        val resolver = TranslationServiceEndpointResolver(
            defaultBaseUrl = "https://translate.vvtech.tech/",
            unitedStatesBaseUrl = " https://translate-us-webrtc.vvtech.tech/ ",
            japanBaseUrl = ""
        )

        assertEquals(
            "https://translate-us-webrtc.vvtech.tech",
            resolver.resolve(TranslationServiceRegion.UnitedStates).baseUrl
        )
        assertEquals(
            TranslationServiceRegion.Default,
            resolver.resolve(TranslationServiceRegion.Japan).region
        )
    }

    private fun resolved(countryIso: String) = TranslationRegionState.Resolved(
        countryIso = countryIso,
        source = TranslationRegionSource.LiveLocation,
        sampledAtMs = 1L
    )

    private class MemoryStore(
        private val strings: MutableMap<String, String> = mutableMapOf(),
        private val booleans: MutableMap<String, Boolean> = mutableMapOf(),
        private val ints: MutableMap<String, Int> = mutableMapOf()
    ) : TranslationCallSettingsStore {
        override fun getString(key: String) = strings[key]
        override fun putString(key: String, value: String) {
            strings[key] = value
        }
        override fun getBoolean(key: String, defaultValue: Boolean) =
            booleans[key] ?: defaultValue
        override fun putBoolean(key: String, value: Boolean) {
            booleans[key] = value
        }
        override fun getInt(key: String, defaultValue: Int) = ints[key] ?: defaultValue
        override fun putInt(key: String, value: Int) {
            ints[key] = value
        }
    }
}
