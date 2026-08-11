package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.data.translation.DefaultTranslationCallSettingsRepository
import com.vvtech.aiassistant.data.translation.TranslationCallSettingsStore
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallLauncherTest {
    @Test
    fun `china freezes selected local sip route and domestic model`() {
        val gateway = FakeGateway()
        val settings = DefaultTranslationCallSettingsRepository(MemoryStore())
        settings.selectDomesticProvider(TranslationRealtimeProvider.Doubao)
        val launcher = launcher(china(), settings, gateway)

        val result = launcher.start(input("+8613800138000"))

        assertTrue(result is TranslationCallLaunchResult.Started)
        assertEquals(TranslationCallTransport.LocalSipDomestic, gateway.request?.plan?.transport)
        assertEquals(TranslationRealtimeProvider.Doubao, gateway.request?.plan?.provider)
        assertEquals("21311780", gateway.request?.plan?.sipAccountId)
    }

    @Test
    fun `china foreign number uses selected international sip`() {
        val gateway = FakeGateway()
        val launcher = launcher(
            china(),
            DefaultTranslationCallSettingsRepository(MemoryStore()),
            gateway
        )

        launcher.start(input("+81333445111"))

        assertEquals(
            TranslationCallTransport.LocalSipInternational,
            gateway.request?.plan?.transport
        )
        assertEquals("1008", gateway.request?.plan?.sipAccountId)
    }

    @Test
    fun `overseas china number uses backend and ignores sip accounts`() {
        val gateway = FakeGateway()
        val settings = DefaultTranslationCallSettingsRepository(MemoryStore())
        settings.selectOverseasProvider(TranslationRealtimeProvider.OpenAi)
        val launcher = launcher(overseas(), settings, gateway)

        launcher.start(input("+8613800138000"))

        assertEquals(TranslationCallTransport.BackendWebRtc, gateway.request?.plan?.transport)
        assertEquals(TranslationRealtimeProvider.OpenAi, gateway.request?.plan?.provider)
        assertNull(gateway.request?.plan?.sipAccountId)
    }

    @Test
    fun `unknown region rejects without opening any transport`() {
        val gateway = FakeGateway()
        val launcher = launcher(
            TranslationRegionState.Unavailable("定位失败"),
            DefaultTranslationCallSettingsRepository(MemoryStore()),
            gateway
        )

        val result = launcher.start(input("+8613800138000"))

        assertTrue(result is TranslationCallLaunchResult.Rejected)
        assertNull(gateway.request)
    }

    @Test
    fun `doubao rejects unsupported language pair before opening transport`() {
        val gateway = FakeGateway()
        val settings = DefaultTranslationCallSettingsRepository(MemoryStore())
        settings.selectDomesticProvider(TranslationRealtimeProvider.Doubao)
        val launcher = launcher(china(), settings, gateway)

        val result = launcher.start(input("+8613800138000", myLanguage = "ja", peerLanguage = "de"))

        assertTrue(result is TranslationCallLaunchResult.Rejected)
        assertEquals(
            "豆包实时翻译暂不支持该语种组合，请选择中文或英语作为其中一种语言",
            (result as TranslationCallLaunchResult.Rejected).message
        )
        assertNull(gateway.request)
    }

    @Test
    fun `doubao accepts supported language pair with chinese or english pivot`() {
        val gateway = FakeGateway()
        val settings = DefaultTranslationCallSettingsRepository(MemoryStore())
        settings.selectDomesticProvider(TranslationRealtimeProvider.Doubao)
        val launcher = launcher(china(), settings, gateway)

        val result = launcher.start(input("+8613800138000", myLanguage = "pt", peerLanguage = "en"))

        assertTrue(result is TranslationCallLaunchResult.Started)
        assertEquals(TranslationRealtimeProvider.Doubao, gateway.request?.plan?.provider)
        assertEquals("pt", gateway.request?.myLanguage)
        assertEquals("en", gateway.request?.peerLanguage)
    }

    @Test
    fun `qwen keeps existing language pair behavior`() {
        val gateway = FakeGateway()
        val launcher = launcher(
            china(),
            DefaultTranslationCallSettingsRepository(MemoryStore()),
            gateway
        )

        val result = launcher.start(input("+8613800138000", myLanguage = "ja", peerLanguage = "de"))

        assertTrue(result is TranslationCallLaunchResult.Started)
        assertEquals(TranslationRealtimeProvider.Qwen, gateway.request?.plan?.provider)
        assertEquals("ja", gateway.request?.myLanguage)
        assertEquals("de", gateway.request?.peerLanguage)
    }

    private fun launcher(
        region: TranslationRegionState,
        settings: DefaultTranslationCallSettingsRepository,
        gateway: FakeGateway
    ) = TranslationCallLauncher(
        coordinator = TranslationCallCoordinator(gateway, idFactory = { "call-1" }),
        regionRepository = FakeRegionRepository(region),
        settingsRepository = settings
    )

    private fun input(
        number: String,
        myLanguage: String = "zh",
        peerLanguage: String = "en"
    ) = TranslationCallLaunchInput(
        rawNumber = number,
        defaultCountryDialCode = "+86",
        myLanguage = myLanguage,
        peerLanguage = peerLanguage,
        domesticSipAccountId = "21311780",
        internationalSipAccountId = "1008"
    )

    private fun china() = TranslationRegionState.Resolved(
        "CN",
        TranslationRegionSource.LiveLocation,
        1L
    )

    private fun overseas() = TranslationRegionState.Resolved(
        "US",
        TranslationRegionSource.LiveLocation,
        1L
    )

    private class FakeRegionRepository(
        initial: TranslationRegionState
    ) : TranslationRegionRepository {
        private val mutableState = MutableStateFlow(initial)
        override val state: StateFlow<TranslationRegionState> = mutableState
        override suspend fun refresh(): TranslationRegionState = state.value
    }

    private class MemoryStore : TranslationCallSettingsStore {
        private val strings = mutableMapOf<String, String>()
        private val booleans = mutableMapOf<String, Boolean>()
        private val ints = mutableMapOf<String, Int>()
        override fun getString(key: String): String? = strings[key]
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

    @Test
    fun `original audio settings are snapshotted for every translation route`() {
        val domesticStore = MemoryStore()
        val domesticSettings = DefaultTranslationCallSettingsRepository(domesticStore)
        domesticSettings.setPlayOriginalAudio(true)
        domesticSettings.setOriginalAudioGainPercent(90)
        domesticSettings.setOriginalAudioVolumePercent(70)
        val domesticGateway = FakeGateway()
        launcher(china(), domesticSettings, domesticGateway).start(input("+8613800138000"))

        assertTrue(requireNotNull(domesticGateway.request).playOriginalAudio)
        assertEquals(50, requireNotNull(domesticGateway.request).originalAudioGainPercent)
        assertEquals(70, requireNotNull(domesticGateway.request).originalAudioVolumePercent)
        domesticSettings.setOriginalAudioVolumePercent(20)
        assertEquals(70, requireNotNull(domesticGateway.request).originalAudioVolumePercent)

        val overseasStore = MemoryStore()
        val overseasSettings = DefaultTranslationCallSettingsRepository(overseasStore)
        overseasSettings.setPlayOriginalAudio(true)
        overseasSettings.setOriginalAudioGainPercent(90)
        overseasSettings.setOriginalAudioVolumePercent(60)
        val overseasGateway = FakeGateway()
        launcher(overseas(), overseasSettings, overseasGateway).start(input("+14155552671"))

        assertTrue(requireNotNull(overseasGateway.request).playOriginalAudio)
        assertEquals(50, requireNotNull(overseasGateway.request).originalAudioGainPercent)
        assertEquals(60, requireNotNull(overseasGateway.request).originalAudioVolumePercent)
    }

    private class FakeGateway : TranslationCallSessionGateway {
        var request: TranslationCallSessionRequest? = null
        override fun start(
            request: TranslationCallSessionRequest,
            onEvent: (TranslationCallSessionEvent) -> Unit
        ) {
            this.request = request
        }
        override fun setMuted(muted: Boolean) = Unit
        override fun setSpeakerEnabled(enabled: Boolean) = Unit
        override fun sendDtmf(digit: Char) = Unit
        override fun hangup() = Unit
        override fun release() = Unit
    }
}
