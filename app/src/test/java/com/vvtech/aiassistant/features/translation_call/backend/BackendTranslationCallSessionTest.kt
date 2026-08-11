package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.domain.translation.TranslationCallPlan
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest
import java.util.concurrent.CountDownLatch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackendTranslationCallSessionTest {
    @Test
    fun `starts merchant only after room and realtime are ready`() {
        val liveKit = FakeLiveKit(emitRealtimeReady = true)
        val client = FakeClient(liveKit = liveKit)
        val events = mutableListOf<TranslationCallSessionEvent>()
        val session = session(client, liveKit, FakeAppAudio(), events)

        session.run()

        assertEquals(1, client.merchantStarts)
        assertEquals("zh-CN", client.createRequest?.userLanguage)
        assertEquals("en-US", client.createRequest?.merchantLanguage)
        assertEquals(
            "google-gemini-live-translate",
            client.createRequest?.realtimeProvider
        )
        assertTrue(events.hasPhase(TranslationCallPhase.Dialing))
        assertTrue(events.hasPhase(TranslationCallPhase.Translating))
        assertTrue(events.last() is TranslationCallSessionEvent.Ended)
    }

    @Test
    fun `maps original audio settings into backend create request`() {
        val liveKit = FakeLiveKit(emitRealtimeReady = true)
        val client = FakeClient(liveKit = liveKit)
        val events = mutableListOf<TranslationCallSessionEvent>()
        val session = session(
            client = client,
            liveKit = liveKit,
            socket = FakeAppAudio(),
            events = events,
            request = request(
                playOriginalAudio = true,
                originalAudioGainPercent = 90,
                originalAudioVolumePercent = 70
            )
        )

        session.run()

        val createRequest = requireNotNull(client.createRequest)
        assertTrue(createRequest.originalAudioEnabled)
        assertEquals(50, createRequest.originalAudioPercent)
        assertEquals(70, createRequest.originalAudioVolumePercent)
    }

    @Test
    fun `keeps backend original audio enabled for pure original only`() {
        val liveKit = FakeLiveKit(emitRealtimeReady = true)
        val client = FakeClient(liveKit = liveKit)
        val events = mutableListOf<TranslationCallSessionEvent>()
        val session = session(
            client = client,
            liveKit = liveKit,
            socket = FakeAppAudio(),
            events = events,
            request = request(playOriginalAudio = true, originalAudioGainPercent = 0)
        )

        session.run()

        val createRequest = requireNotNull(client.createRequest)
        assertEquals(true, createRequest.originalAudioEnabled)
        assertEquals(0, createRequest.originalAudioPercent)
        assertEquals(100, createRequest.originalAudioVolumePercent)
    }

    @Test
    fun `disables backend original audio when both levels are zero`() {
        val liveKit = FakeLiveKit(emitRealtimeReady = true)
        val client = FakeClient(liveKit = liveKit)
        val events = mutableListOf<TranslationCallSessionEvent>()
        val session = session(
            client = client,
            liveKit = liveKit,
            socket = FakeAppAudio(),
            events = events,
            request = request(
                playOriginalAudio = true,
                originalAudioGainPercent = 0,
                originalAudioVolumePercent = 0
            )
        )

        session.run()

        val createRequest = requireNotNull(client.createRequest)
        assertEquals(false, createRequest.originalAudioEnabled)
        assertEquals(0, createRequest.originalAudioPercent)
        assertEquals(0, createRequest.originalAudioVolumePercent)
    }

    @Test
    fun `falls back to app audio after livekit ready timeout`() {
        val liveKit = FakeLiveKit(emitRealtimeReady = false)
        val socket = FakeAppAudio()
        val client = FakeClient(liveKit = liveKit, socket = socket)
        val events = mutableListOf<TranslationCallSessionEvent>()
        var waits = 0
        val session = session(
            client,
            liveKit,
            socket,
            events,
            awaitReady = { _: CountDownLatch, _: Long ->
                waits += 1
                waits > 1
            }
        )

        session.run()

        assertTrue(liveKit.closed)
        assertTrue(socket.connected)
        assertEquals(events.toString(), 1, client.merchantStarts)
        assertTrue(events.last() is TranslationCallSessionEvent.Ended)
    }

    @Test
    fun `falls back to app audio when livekit fails before ready`() {
        val liveKit = FakeLiveKit(emitRealtimeReady = false, failBeforeReady = true)
        val socket = FakeAppAudio()
        val client = FakeClient(liveKit = liveKit, socket = socket)
        val events = mutableListOf<TranslationCallSessionEvent>()

        session(client, liveKit, socket, events).run()

        assertTrue(liveKit.closed)
        assertTrue(socket.connected)
        assertEquals(1, client.merchantStarts)
        assertTrue(events.last() is TranslationCallSessionEvent.Ended)
    }

    private fun session(
        client: FakeClient,
        liveKit: FakeLiveKit,
        socket: FakeAppAudio,
        events: MutableList<TranslationCallSessionEvent>,
        request: TranslationCallSessionRequest = request(),
        awaitReady: (CountDownLatch, Long) -> Boolean =
            { latch, timeout -> latch.await(timeout, java.util.concurrent.TimeUnit.MILLISECONDS) }
    ) = BackendTranslationCallRuntimeSession(
        request = request,
        client = client,
        liveKit = liveKit,
        appAudio = socket,
        audioBridge = FakeAudioBridge(),
        onEvent = events::add,
        awaitReady = awaitReady
    )

    private fun request(
        playOriginalAudio: Boolean = false,
        originalAudioGainPercent: Int = 50,
        originalAudioVolumePercent: Int = 100
    ) = TranslationCallSessionRequest(
        callId = "call-1",
        plan = TranslationCallPlan(
            locationCountryIso = "US",
            locationSource = TranslationRegionSource.LiveLocation,
            targetE164 = "+14155550100",
            transport = TranslationCallTransport.BackendWebRtc,
            provider = TranslationRealtimeProvider.Gemini,
            sipAccountId = null,
            serviceRegion = TranslationServiceRegion.UnitedStates
        ),
        myLanguage = "zh",
        peerLanguage = "en",
        playOriginalAudio = playOriginalAudio,
        originalAudioGainPercent = originalAudioGainPercent,
        originalAudioVolumePercent = originalAudioVolumePercent
    )

    private fun List<TranslationCallSessionEvent>.hasPhase(phase: TranslationCallPhase) =
        any { it is TranslationCallSessionEvent.PhaseChanged && it.phase == phase }

    private class FakeClient(
        private val liveKit: FakeLiveKit,
        private val socket: FakeAppAudio? = null
    ) : BackendTranslationClient {
        var merchantStarts = 0
        var createRequest: BackendCreateCallRequest? = null
        override fun loadLanguageCatalog() = BackendTranslationLanguageCatalog(
            listOf(
                BackendTranslationLanguage("zh-CN", "Chinese"),
                BackendTranslationLanguage("en-US", "English")
            )
        )
        override fun createSession(request: BackendCreateCallRequest) =
            BackendTranslationCallSession(
                callSessionId = "backend-1",
                status = "ready",
                appAudioWsUrl = "wss://fallback.example",
                mediaTransport = BackendMediaTransport.LiveKit,
                liveKit = BackendLiveKitConnection("wss://room", "token", "room", "user"),
                voiceProvider = "twilio",
                realtimeProvider = "gemini",
                environment = null
            ).also { createRequest = request }

        override fun startMerchantCall(
            request: BackendStartMerchantCallRequest
        ): BackendStartMerchantCallResult {
            merchantStarts += 1
            liveKit.emitMerchantReady()
            socket?.emitMerchantReady()
            liveKit.emitEnded()
            socket?.emitEnded()
            return BackendStartMerchantCallResult(true, null)
        }

        override fun hangup(request: BackendHangupRequest) = Unit
    }

    private class FakeLiveKit(
        private val emitRealtimeReady: Boolean,
        private val failBeforeReady: Boolean = false
    ) : BackendLiveKitTransport {
        var listener: BackendLiveKitTransport.Listener? = null
        var closed = false
        override fun connect(
            connection: BackendLiveKitConnection,
            listener: BackendLiveKitTransport.Listener
        ) {
            this.listener = listener
            if (failBeforeReady) {
                listener.onError("connect failed")
                return
            }
            listener.onRoomReady()
            if (emitRealtimeReady) listener.onControlMessage(message("realtime_ready"))
        }
        override fun setMuted(muted: Boolean) = Unit
        override fun setSpeakerEnabled(enabled: Boolean) = Unit
        override fun close() {
            closed = true
        }
        fun emitMerchantReady() = listener?.onControlMessage(message("merchant_audio_ready"))
        fun emitEnded() = listener?.onControlMessage(message("call_ended"))
    }

    private class FakeAppAudio : BackendAppAudioTransport {
        var listener: BackendAppAudioTransport.Listener? = null
        var connected = false
        override fun connect(
            wsUrl: String,
            callSessionId: String,
            listener: BackendAppAudioTransport.Listener
        ) {
            connected = true
            this.listener = listener
            listener.onMessage(message("app_audio_ready"))
        }
        override fun sendPcm16(pcmLittleEndian: ByteArray, sampleRate: Int) = true
        override fun close() = Unit
        fun emitMerchantReady() = listener?.onMessage(message("merchant_audio_ready"))
        fun emitEnded() = listener?.onMessage(message("call_ended"))
    }

    private class FakeAudioBridge : BackendPcmAudioBridge {
        override fun start(onPcm16: (ByteArray) -> Unit, onError: (String) -> Unit) = Unit
        override fun play(audio: BackendRealtimeEvent.TranslatedAudio) = Unit
        override fun setMuted(muted: Boolean) = Unit
        override fun setSpeakerEnabled(enabled: Boolean) = Unit
        override fun close() = Unit
    }

    private companion object {
        fun message(event: String) = BackendRealtimeMessage(
            callSessionId = "backend-1",
            environment = null,
            event = when (event) {
                "realtime_ready" -> BackendRealtimeEvent.Ready(
                    BackendRealtimeEvent.Ready.Kind.Realtime
                )
                "app_audio_ready" -> BackendRealtimeEvent.Ready(
                    BackendRealtimeEvent.Ready.Kind.AppAudio
                )
                "merchant_audio_ready" -> BackendRealtimeEvent.Ready(
                    BackendRealtimeEvent.Ready.Kind.MerchantAudio
                )
                else -> BackendRealtimeEvent.CallEnded("done")
            }
        )
    }
}
