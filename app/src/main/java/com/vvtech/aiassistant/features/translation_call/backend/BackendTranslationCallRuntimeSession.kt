package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

internal class BackendTranslationCallRuntimeSession(
    private val request: TranslationCallSessionRequest,
    private val client: BackendTranslationClient,
    private val liveKit: BackendLiveKitTransport,
    private val appAudio: BackendAppAudioTransport,
    private val audioBridge: BackendPcmAudioBridge,
    private val onEvent: (TranslationCallSessionEvent) -> Unit,
    private val awaitReady: (CountDownLatch, Long) -> Boolean =
        { latch, timeout -> latch.await(timeout, TimeUnit.MILLISECONDS) }
) {
    private enum class ActiveMedia { None, LiveKit, AppAudio }

    private val active = AtomicBoolean(true)
    private val terminal = AtomicBoolean()
    private val merchantConnected = AtomicBoolean()
    private val audioStarted = AtomicBoolean()
    private val mediaReady = AtomicBoolean()
    private val transcriptAccumulator = BackendTranscriptAccumulator()
    private var backendSession: BackendTranslationCallSession? = null
    private var media = ActiveMedia.None
    private var readyLatch = CountDownLatch(1)

    fun run() {
        try {
            val catalog = client.loadLanguageCatalog()
            val userLanguage = BackendTranslationLanguageMapper.resolve(
                request.myLanguage,
                catalog
            )
            val merchantLanguage = BackendTranslationLanguageMapper.resolve(
                request.peerLanguage,
                catalog
            )
            val created = client.createSession(
                createRequest(userLanguage.code, merchantLanguage.code)
            )
            backendSession = created
            created.environment?.let(::emitEnvironment)
            val ready = startPreferredMedia(created)
            if (!ready || !active.get()) {
                fail("实时媒体通道准备超时，请重试")
                return
            }
            emitPhase(TranslationCallPhase.Dialing)
            val merchantResult = BackendMerchantCallStarter(client).start(
                BackendStartMerchantCallRequest(
                    callSessionId = created.callSessionId,
                    merchantPhone = request.plan.targetE164,
                    voiceProvider = created.voiceProvider,
                    userId = DefaultUserId
                ),
                ::emitEnvironment
            )
            if (!merchantResult.started) {
                fail("后端未能发起被叫呼叫")
                return
            }
            if (!merchantConnected.get()) emitPhase(TranslationCallPhase.Ringing)
            while (active.get() && !terminal.get()) {
                Thread.sleep(TerminalPollMs)
            }
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            if (active.get()) fail("实时翻译通话已中断")
        } catch (error: Exception) {
            fail(error.message ?: "后端实时翻译通话失败")
        } finally {
            closeMedia()
        }
    }

    fun setMuted(muted: Boolean) {
        liveKit.setMuted(muted)
        audioBridge.setMuted(muted)
    }

    fun setSpeakerEnabled(enabled: Boolean) {
        liveKit.setSpeakerEnabled(enabled)
        audioBridge.setSpeakerEnabled(enabled)
    }

    fun hangup() {
        if (!active.getAndSet(false)) return
        backendSession?.let {
            runCatching { client.hangup(BackendHangupRequest(it.callSessionId, DefaultUserId)) }
        }
        if (terminal.compareAndSet(false, true)) {
            onEvent(TranslationCallSessionEvent.Ended(request.callId))
        }
        closeMedia()
    }

    private fun startPreferredMedia(created: BackendTranslationCallSession): Boolean {
        val connection = created.liveKit
        if (
            created.mediaTransport.equals(BackendMediaTransport.LiveKit, true) &&
            connection != null
        ) {
            readyLatch = CountDownLatch(1)
            mediaReady.set(false)
            media = ActiveMedia.LiveKit
            liveKit.connect(connection, liveKitListener(created.callSessionId))
            if (awaitReady(readyLatch, ReadyTimeoutMs) && mediaReady.get()) return true
            liveKit.close()
            media = ActiveMedia.None
        }
        if (created.appAudioWsUrl.isBlank()) return false
        readyLatch = CountDownLatch(1)
        mediaReady.set(false)
        media = ActiveMedia.AppAudio
        appAudio.connect(
            created.appAudioWsUrl,
            created.callSessionId,
            appAudioListener(created.callSessionId)
        )
        return awaitReady(readyLatch, ReadyTimeoutMs) && mediaReady.get()
    }

    private fun liveKitListener(
        callSessionId: String
    ) = object : BackendLiveKitTransport.Listener {
        private val roomReady = AtomicBoolean()
        private val realtimeReady = AtomicBoolean()
        private val linkReady = AtomicBoolean()

        override fun onRoomReady() {
            roomReady.set(true)
            signalLiveKitReady()
        }

        override fun onControlMessage(message: BackendRealtimeMessage) {
            if (!accepts(message.callSessionId, callSessionId)) return
            if (
                message.event is BackendRealtimeEvent.Ready &&
                message.event.kind == BackendRealtimeEvent.Ready.Kind.Realtime
            ) {
                realtimeReady.set(true)
                signalLiveKitReady()
            }
            handleMessage(message)
        }

        override fun onLinkAvailable(available: Boolean) = Unit
        override fun onError(message: String) {
            if (linkReady.get()) fail(message) else readyLatch.countDown()
        }
        override fun onDisconnected() {
            if (linkReady.get()) fail("LiveKit 连接已断开") else readyLatch.countDown()
        }

        private fun signalLiveKitReady() {
            if (roomReady.get() && realtimeReady.get()) {
                linkReady.set(true)
                mediaReady.set(true)
                readyLatch.countDown()
            }
        }
    }

    private fun appAudioListener(
        callSessionId: String
    ) = object : BackendAppAudioTransport.Listener {
        override fun onOpen() = Unit

        override fun onMessage(message: BackendRealtimeMessage) {
            if (!accepts(message.callSessionId, callSessionId)) return
            if (
                message.event is BackendRealtimeEvent.Ready &&
                message.event.kind == BackendRealtimeEvent.Ready.Kind.AppAudio
            ) {
                mediaReady.set(true)
                readyLatch.countDown()
            }
            handleMessage(message)
        }

        override fun onError(message: String) {
            readyLatch.countDown()
            fail(message)
        }
        override fun onClosed() {
            if (active.get() && !terminal.get()) fail("实时音频连接已关闭")
        }
    }

    private fun handleMessage(message: BackendRealtimeMessage) {
        message.environment?.let(::emitEnvironment)
        when (val event = message.event) {
            is BackendRealtimeEvent.Ready -> if (
                event.kind == BackendRealtimeEvent.Ready.Kind.MerchantAudio
            ) {
                merchantConnected.set(true)
                emitPhase(TranslationCallPhase.Connected)
                emitPhase(TranslationCallPhase.Translating)
                startAppAudioCaptureIfNeeded()
            }
            is BackendRealtimeEvent.TranslatedAudio -> audioBridge.play(event)
            is BackendRealtimeEvent.TranscriptDelta -> emitTranscript(
                transcriptAccumulator.apply(event, request.myLanguage, request.peerLanguage)
            )
            is BackendRealtimeEvent.ConnectPrompt -> emitTranscript(
                transcriptAccumulator.connectPrompt(event, request.myLanguage, request.peerLanguage)
            )
            is BackendRealtimeEvent.CallEnded -> end()
            is BackendRealtimeEvent.Error -> fail(event.message)
            is BackendRealtimeEvent.EnvironmentSnapshot,
            is BackendRealtimeEvent.Unknown -> Unit
        }
    }

    private fun startAppAudioCaptureIfNeeded() {
        if (media != ActiveMedia.AppAudio || !audioStarted.compareAndSet(false, true)) return
        audioBridge.start(
            onPcm16 = { appAudio.sendPcm16(it, CaptureSampleRate) },
            onError = ::fail
        )
    }

    private fun emitEnvironment(
        patch: com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
    ) {
        onEvent(TranslationCallSessionEvent.EnvironmentChanged(request.callId, patch))
    }

    private fun emitTranscript(
        item: com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem
    ) {
        onEvent(TranslationCallSessionEvent.Transcript(request.callId, item))
    }

    private fun emitPhase(phase: TranslationCallPhase) {
        if (!terminal.get()) {
            onEvent(TranslationCallSessionEvent.PhaseChanged(request.callId, phase))
        }
    }

    private fun fail(message: String) {
        active.set(false)
        if (terminal.compareAndSet(false, true)) {
            onEvent(TranslationCallSessionEvent.Failure(request.callId, message))
        }
    }

    private fun end() {
        active.set(false)
        if (terminal.compareAndSet(false, true)) {
            onEvent(TranslationCallSessionEvent.Ended(request.callId))
        }
    }

    private fun closeMedia() {
        runCatching { liveKit.close() }
        runCatching { appAudio.close() }
        runCatching { audioBridge.close() }
        media = ActiveMedia.None
    }

    private fun createRequest(
        userLanguage: String,
        merchantLanguage: String
    ) = BackendCreateCallRequest(
        merchantPhone = request.plan.targetE164,
        userLanguage = userLanguage,
        merchantLanguage = merchantLanguage,
        userId = DefaultUserId,
        realtimeProvider = BackendRealtimeProviderMapper.toApiValue(request.plan.provider),
        originalAudioEnabled = BackendOriginalAudioRequestPolicy.enabled(
            request.playOriginalAudio,
            request.originalAudioGainPercent,
            request.originalAudioVolumePercent
        ),
        originalAudioPercent = BackendOriginalAudioRequestPolicy.percent(
            request.playOriginalAudio,
            request.originalAudioGainPercent
        ),
        originalAudioVolumePercent = BackendOriginalAudioRequestPolicy.volumePercent(
            request.originalAudioVolumePercent
        )
    )

    private fun accepts(received: String, expected: String): Boolean =
        received.isBlank() || received == expected

    private companion object {
        const val ReadyTimeoutMs = 10_000L
        const val TerminalPollMs = 50L
        const val CaptureSampleRate = 16_000
        const val DefaultUserId = "mobile-app-user"
    }
}
