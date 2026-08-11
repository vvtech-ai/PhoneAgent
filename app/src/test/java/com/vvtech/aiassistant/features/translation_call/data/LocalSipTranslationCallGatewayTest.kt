package com.vvtech.aiassistant.features.translation_call.data

import com.vvtech.aiassistant.callengine.AssistantCallEngineEvent
import com.vvtech.aiassistant.callengine.AssistantCallEngineGateway
import com.vvtech.aiassistant.callengine.AssistantCallPhase
import com.vvtech.aiassistant.callengine.AssistantCallRequest
import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.domain.translation.TranslationCallPlan
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalSipTranslationCallGatewayTest {
    @Test
    fun `maps local plan and engine events into translation session`() {
        val engine = FakeEngine()
        val monitor = FakeMonitor(available())
        val gateway = LocalSipTranslationCallGateway(engine, monitor)
        val events = mutableListOf<TranslationCallSessionEvent>()

        gateway.start(request(), events::add)
        engine.emit(AssistantCallEngineEvent.PhaseChanged(AssistantCallPhase.DIALING))
        engine.emit(AssistantCallEngineEvent.ModelReady)

        assertEquals("+8613800138000", engine.request?.phoneNumber)
        assertEquals("21311775", engine.request?.selectedDomesticSipAccountId)
        assertTrue(requireNotNull(engine.request).playOriginalAudio)
        assertEquals(50, requireNotNull(engine.request).originalAudioGainPercent)
        assertEquals(70, requireNotNull(engine.request).originalAudioVolumePercent)
        assertTrue(monitor.started)
        assertTrue(
            events.any {
                it is TranslationCallSessionEvent.PhaseChanged &&
                    it.phase == TranslationCallPhase.Dialing
            }
        )
        assertTrue(
            events.filterIsInstance<TranslationCallSessionEvent.EnvironmentChanged>()
                .any { it.patch.model?.state == TranslationEnvironmentState.Available }
        )
    }

    @Test
    fun `blocks before sip start when network is unavailable`() {
        val engine = FakeEngine()
        val monitor = FakeMonitor(
            TranslationEnvironmentComponent(
                TranslationEnvironmentState.Unavailable,
                detail = "offline"
            )
        )
        val gateway = LocalSipTranslationCallGateway(engine, monitor)
        val events = mutableListOf<TranslationCallSessionEvent>()

        gateway.start(request(), events::add)

        assertFalse(engine.started)
        assertTrue(events.last() is TranslationCallSessionEvent.Failure)
    }

    @Test
    fun `uses current provider quality as initial model environment`() {
        val engine = FakeEngine()
        val monitor = FakeMonitor(available())
        val probedModel = TranslationEnvironmentComponent(
            state = TranslationEnvironmentState.Available,
            latencyMs = 128L
        )
        val gateway = LocalSipTranslationCallGateway(
            engine,
            monitor,
            modelQualityProvider = {
                TranslationModelNetworkQualityState(
                    components = mapOf(TranslationRealtimeProvider.Qwen to probedModel),
                    sampledAtMs = 1_000L
                )
            }
        )
        val events = mutableListOf<TranslationCallSessionEvent>()

        gateway.start(request(), events::add)

        val initialModel = events.filterIsInstance<TranslationCallSessionEvent.EnvironmentChanged>()
            .first().patch.model
        assertEquals(TranslationEnvironmentState.Available, initialModel?.state)
        assertEquals(128L, initialModel?.latencyMs)
    }

    @Test
    fun `sends planned extension once only after connected`() {
        val engine = FakeEngine()
        val gateway = LocalSipTranslationCallGateway(engine, FakeMonitor(available()))
        val events = mutableListOf<TranslationCallSessionEvent>()
        val request = request(
            targetE164 = "+861088886666",
            networkDialNumber = "01088886666",
            postConnectDtmf = "1234"
        )

        gateway.start(request, events::add)
        assertEquals("01088886666", engine.request?.phoneNumber)
        assertEquals("", engine.sentDtmf.joinToString(""))

        engine.emit(AssistantCallEngineEvent.PhaseChanged(AssistantCallPhase.CONNECTED))
        engine.emit(AssistantCallEngineEvent.PhaseChanged(AssistantCallPhase.TRANSLATING))

        assertEquals("1234", engine.sentDtmf.joinToString(""))
    }

    @Test
    fun `preserves structured sip failure for presentation`() {
        val engine = FakeEngine()
        val monitor = FakeMonitor(available())
        val gateway = LocalSipTranslationCallGateway(engine, monitor)
        val events = mutableListOf<TranslationCallSessionEvent>()

        gateway.start(request(), events::add)
        engine.emit(
            AssistantCallEngineEvent.Failure(
                message = "SIP INVITE 失败：503 Service Unavailable",
                sipMethod = "INVITE",
                sipStatusCode = 503,
                failureKind = CallFailureKind.SERVICE_UNAVAILABLE
            )
        )

        val failure = events.filterIsInstance<TranslationCallSessionEvent.Failure>().last()
        val environment =
            events.filterIsInstance<TranslationCallSessionEvent.EnvironmentChanged>().last()
        assertEquals(CallFailureKind.SERVICE_UNAVAILABLE, failure.failureKind)
        assertEquals("SIP INVITE 失败：503 Service Unavailable", failure.message)
        assertEquals(null, environment.patch.riskMessage)
        assertEquals(null, environment.patch.sip?.detail)
    }

    private fun request(
        targetE164: String = "+8613800138000",
        networkDialNumber: String = targetE164,
        postConnectDtmf: String = ""
    ) = TranslationCallSessionRequest(
        callId = "call-1",
        plan = TranslationCallPlan(
            locationCountryIso = "CN",
            locationSource = TranslationRegionSource.LiveLocation,
            targetE164 = targetE164,
            networkDialNumber = networkDialNumber,
            postConnectDtmf = postConnectDtmf,
            transport = TranslationCallTransport.LocalSipDomestic,
            provider = TranslationRealtimeProvider.Qwen,
            sipAccountId = "21311775",
            serviceRegion = TranslationServiceRegion.Default
        ),
        myLanguage = "zh",
        peerLanguage = "en",
        playOriginalAudio = true,
        originalAudioGainPercent = 50,
        originalAudioVolumePercent = 70
    )

    private fun available() =
        TranslationEnvironmentComponent(TranslationEnvironmentState.Available)

    private class FakeMonitor(
        private val current: TranslationEnvironmentComponent
    ) : LocalTranslationEnvironmentMonitor {
        var started = false
        override fun currentNetwork() = current
        override fun start(onNetworkChanged: (TranslationEnvironmentComponent) -> Unit) {
            started = true
        }
        override fun stop() {
            started = false
        }
    }

    private class FakeEngine : AssistantCallEngineGateway {
        var request: AssistantCallRequest? = null
        var started = false
        val sentDtmf = mutableListOf<Char>()
        private var listener: ((AssistantCallEngineEvent) -> Unit)? = null
        override fun start(
            request: AssistantCallRequest,
            onEvent: (AssistantCallEngineEvent) -> Unit
        ) {
            this.request = request
            started = true
            listener = onEvent
        }
        override fun setMuted(muted: Boolean) = Unit
        override fun setSpeakerEnabled(enabled: Boolean) = Unit
        override fun sendDtmf(digit: Char) {
            sentDtmf += digit
        }
        override fun hangup() = Unit
        override fun release() = Unit
        fun emit(event: AssistantCallEngineEvent) = listener?.invoke(event)
    }
}
