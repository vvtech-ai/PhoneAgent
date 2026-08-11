package com.vvtech.aiassistant.callengine

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.SocketTimeoutException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.random.Random
internal class AndroidSipMediaBridge(
    private val context: Context,
    private val socket: DatagramSocket,
    private val endpoint: AssistantSipRemoteAudioEndpoint,
    private val translator: AssistantRealtimeTranslationProcessor?,
    private val traceId: String,
    private val playOriginalAudio: Boolean,
    originalAudioGainPercent: Int,
    originalAudioVolumePercent: Int,
    initialSpeakerEnabled: Boolean,
    private val translationIntroSpec: AssistantTranslationIntroSpec? = null,
    private val onFailure: (String) -> Unit
) : AutoCloseable {
    private val active = AtomicBoolean(false)
    private val muted = AtomicBoolean(false)
    private val translationIntroGate = AssistantTranslationIntroGate()
    private val sendLock = Any()
    private val ssrc = Random.nextLong().and(0xFFFFFFFFL)
    private var sequence = Random.nextInt(0, 65_536)
    private var timestamp = Random.nextLong().and(0xFFFFFFFFL)
    private var record: AudioRecord? = null
    private var captureThread: Thread? = null
    private var receiveThread: Thread? = null
    private var translationIntroCoordinator: AssistantTranslationIntroCoordinator? = null
    private val audioOutput = AndroidSipAudioOutput(
        context,
        initialSpeakerEnabled,
        onFailure
    )
    private val originalAudioMixGain = AssistantOriginalAudioGainCurve.gain(
        originalAudioGainPercent
    )
    private val originalAudioPureGain = AssistantOriginalAudioGainCurve.gain(
        originalAudioVolumePercent
    )
    private val translatedUplink = translator?.takeUnless { playOriginalAudio }?.let {
        AssistantTranslatedUplinkPlayout(traceId, ::sendPcm16kToSip, onFailure)
    }
    private val localMixPlayout = translator?.takeIf { playOriginalAudio }?.let {
        AssistantOriginalAudioMixPlayout(
            traceId = traceId,
            direction = "local_to_sip",
            targetOriginalRatio = originalAudioMixGain,
            pureOriginalGain = originalAudioPureGain,
            maxOriginalGain = if (it.originalAudioDynamicBoostEnabled) {
                null
            } else {
                originalAudioMixGain
            },
            responseBoundarySupported = it.translatedAudioCompletionSupported,
            outputFrame = ::sendPcm16kToSip,
            onFailure = onFailure
        )
    }
    private val remoteMixPlayout = translator?.takeIf { playOriginalAudio }?.let {
        AssistantOriginalAudioMixPlayout(
            traceId = traceId,
            direction = "remote_to_local",
            targetOriginalRatio = originalAudioMixGain,
            pureOriginalGain = originalAudioPureGain,
            maxOriginalGain = if (it.originalAudioDynamicBoostEnabled) {
                null
            } else {
                originalAudioMixGain
            },
            responseBoundarySupported = it.translatedAudioCompletionSupported,
            outputFrame = ::playPcm16k,
            onFailure = onFailure
        )
    }
    private val translationIntroRemotePlayback = AssistantTranslationIntroRemotePlayback(
        traceId = traceId,
        outputFrame = ::sendPcm16kToSip,
        onFailure = onFailure,
        isCallActive = active::get
    )

    fun start() {
        if (!active.compareAndSet(false, true)) return
        audioOutput.start()
        translatedUplink?.start()
        localMixPlayout?.start()
        remoteMixPlayout?.start()
        translationIntroCoordinator = createTranslationIntroCoordinator()
        translationIntroCoordinator?.start()
        translator?.start()
        captureThread = thread(name = "assistant-sip-capture", isDaemon = true) { captureLoop() }
        receiveThread = thread(name = "assistant-sip-receive", isDaemon = true) { receiveLoop() }
    }

    fun setMuted(enabled: Boolean) = muted.set(enabled)

    fun setSpeakerEnabled(enabled: Boolean) = audioOutput.setSpeakerEnabled(enabled)

    fun sendDtmf(key: Char, durationMillis: Int = 160): Boolean {
        val payloadType = endpoint.telephoneEventPayloadType ?: return false
        if (!active.get()) return false
        val remote = InetSocketAddress(InetAddress.getByName(endpoint.address), endpoint.port)
        synchronized(sendLock) {
            val packets = AssistantRtpTelephoneEventPacketizer.packetize(
                key = key,
                payloadType = payloadType,
                startSequence = sequence,
                startTimestamp = timestamp,
                ssrc = ssrc,
                durationMillis = durationMillis
            )
            if (packets.isEmpty()) return false
            packets.forEachIndexed { index, packet ->
                if (!active.get()) return false
                socket.send(DatagramPacket(packet, packet.size, remote))
                sequence = (sequence + 1) and 0xFFFF
                if (index < packets.lastIndex) Thread.sleep(DtmfFrameMillis.toLong())
            }
            timestamp = (timestamp + durationMillis.coerceAtLeast(DtmfFrameMillis) * 8L) and
                0xFFFFFFFFL
            return true
        }
    }

    fun sendTranslatedPcm16kToSip(pcm16k: ShortArray) {
        if (!active.get()) return
        if (translationIntroGate.shouldSuppressModelOutput()) return
        if (playOriginalAudio) localMixPlayout?.enqueueTranslated(pcm16k)
        else translatedUplink?.enqueue(pcm16k)
    }

    fun playTranslatedPcm16kLocally(pcm16k: ShortArray) {
        if (!active.get()) return
        if (translationIntroGate.shouldSuppressModelOutput()) return
        if (playOriginalAudio) remoteMixPlayout?.enqueueTranslated(pcm16k)
        else playPcm16k(pcm16k)
    }

    fun markTranslatedAudioCompleted(toSip: Boolean) =
        (if (toSip) localMixPlayout else remoteMixPlayout)?.markTranslationResponseDone()

    fun markTranslationIntroModelReady() {
        translationIntroCoordinator?.markModelReady()
    }

    fun shouldSuppressTranslationIntroOutput(): Boolean = translationIntroGate.shouldSuppressModelOutput()

    @SuppressLint("MissingPermission")
    private fun captureLoop() {
        val minBuffer = AudioRecord.getMinBufferSize(
            ProviderSampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
            fail("麦克风初始化失败")
            return
        }
        val audioRecord = runCatching {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                ProviderSampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer, ProviderFrameSamples * 8)
            )
        }.getOrElse {
            fail(it.message ?: "麦克风初始化失败")
            return
        }
        record = audioRecord
        if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
            fail("麦克风不可用")
            return
        }
        runCatching { audioRecord.startRecording() }.onFailure {
            fail(it.message ?: "麦克风启动失败")
            return
        }
        val frame = ShortArray(ProviderFrameSamples)
        while (active.get()) {
            val count = audioRecord.read(frame, 0, frame.size, AudioRecord.READ_BLOCKING)
            if (count <= 0) continue
            val pcm = frame.copyOf(count)
            if (muted.get()) pcm.fill(0)
            if (translator == null) {
                sendPcm16kToSip(pcm)
            } else {
                if (translationIntroGate.shouldSuppressLiveInput()) continue
                if (playOriginalAudio) localMixPlayout?.enqueueOriginal(pcm)
                translator.onLocalPcm16k(pcm)
            }
        }
    }

    private fun receiveLoop() {
        val buffer = ByteArray(2_048)
        runCatching { socket.soTimeout = 1_000 }
        while (active.get()) {
            try {
                val datagram = DatagramPacket(buffer, buffer.size)
                socket.receive(datagram)
                val packet = AssistantRtpPacketCodec.parse(datagram.data, datagram.length) ?: continue
                if (packet.payloadType != endpoint.payloadType) continue
                val pcm8k = AssistantG711Codec.decode(endpoint.codec, packet.payload)
                val pcm16k = AssistantPcmResampler.resample(pcm8k, SipSampleRate, ProviderSampleRate)
                if (translator == null) {
                    playPcm16k(pcm16k)
                } else {
                    if (translationIntroGate.shouldSuppressLiveInput()) continue
                    if (playOriginalAudio) remoteMixPlayout?.enqueueOriginal(pcm16k)
                    translator.onRemotePcm16k(pcm16k)
                }
            } catch (_: SocketTimeoutException) {
                Unit
            } catch (error: Exception) {
                if (active.get()) fail(error.message ?: "RTP 音频接收失败")
            }
        }
    }

    private fun sendPcm16kToSip(pcm16k: ShortArray) {
        val pcm8k = AssistantPcmResampler.resample(pcm16k, ProviderSampleRate, SipSampleRate)
        val remote = InetSocketAddress(InetAddress.getByName(endpoint.address), endpoint.port)
        synchronized(sendLock) {
            for (offset in pcm8k.indices step SipFrameSamples) {
                if (!active.get()) return
                val frame = ShortArray(SipFrameSamples)
                val copyLength = minOf(SipFrameSamples, pcm8k.size - offset)
                System.arraycopy(pcm8k, offset, frame, 0, copyLength)
                val payload = AssistantG711Codec.encode(endpoint.codec, frame)
                val packet = AssistantRtpPacketCodec.build(
                    payloadType = endpoint.payloadType,
                    sequenceNumber = sequence,
                    timestamp = timestamp,
                    ssrc = ssrc,
                    payload = payload
                )
                socket.send(DatagramPacket(packet, packet.size, remote))
                sequence = (sequence + 1) and 0xFFFF
                timestamp = (timestamp + SipFrameSamples) and 0xFFFFFFFFL
            }
        }
    }

    private fun createTranslationIntroCoordinator(): AssistantTranslationIntroCoordinator? {
        val translation = translator ?: return null
        val spec = translationIntroSpec ?: return null
        if (!AssistantTranslationConnectPromptPolicy.isEnabled(AssistantCallMode.TRANSLATION)) {
            return null
        }
        var coordinator: AssistantTranslationIntroCoordinator? = null
        val responseBoundarySupported = translation.setIntroTriggerResponseListener {
            coordinator?.markModelTriggerResponseDone()
        }
        coordinator = AssistantTranslationIntroCoordinator(
            spec = spec,
            callbacks = AssistantTranslationIntroCallbacks(
                playLocalFrame = ::playPcm16k,
                playRemoteFrames = translationIntroRemotePlayback::play,
                sendModelLocalFrame = translation::onLocalPcm16k,
                isCallActive = active::get,
                onFailure = onFailure
            ),
            gate = translationIntroGate,
            loadFrames = { language -> AssistantTranslationIntroAudio.loadFrames(context, language) },
            loadTriggerFrames = { AssistantTranslationIntroAudio.loadTriggerFrames(context) },
            expectTriggerResponseBoundary = responseBoundarySupported
        )
        return coordinator
    }

    private fun playPcm16k(pcm16k: ShortArray) {
        audioOutput.play(pcm16k)
    }

    private fun fail(message: String) {
        if (active.get()) onFailure(message)
    }

    override fun close() {
        if (!active.getAndSet(false)) return
        runCatching { record?.stop() }
        runCatching { record?.release() }
        runCatching { translationIntroCoordinator?.close() }
        runCatching { translationIntroRemotePlayback.close() }
        runCatching { audioOutput.close() }
        runCatching { translatedUplink?.close() }
        runCatching { localMixPlayout?.close() }
        runCatching { remoteMixPlayout?.close() }
        runCatching { translator?.close() }
        translationIntroCoordinator = null
        record = null
        captureThread?.interrupt()
        receiveThread?.interrupt()
    }

    private companion object {
        const val ProviderSampleRate = 16_000
        const val SipSampleRate = 8_000
        const val ProviderFrameSamples = 320
        const val SipFrameSamples = 160
        const val DtmfFrameMillis = 20
    }
}
