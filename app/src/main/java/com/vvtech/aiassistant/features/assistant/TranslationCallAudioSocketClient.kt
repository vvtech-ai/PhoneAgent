package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.os.Build
import android.os.SystemClock
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.features.assistant_translation.TranslationCallAudioCaptureConfigPolicy
import com.vvtech.aiassistant.features.assistant_translation.TranslationCallAudioPcmPolicy
import com.vvtech.aiassistant.features.assistant_translation.TranslationCallAudioTargetSampleRate
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import okio.ByteString
import okio.ByteString.Companion.toByteString

/**
 * Dedicated app-side audio tunnel for realtime translation calls.
 * This phase wires microphone uplink and leaves room for translated-audio
 * downlink once the backend media bridge is fully connected.
 */
class TranslationCallAudioSocketClient(
    private val context: Context
) {

    sealed interface Event {
        data class Status(val message: String) : Event
        data class Error(val message: String) : Event
        object Connected : Event
        object Closed : Event
    }

    private companion object {
        private const val TAG = "TranslationCallAudio"
    }

    private val httpClient = OkHttpClient.Builder().build()
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private val connected = AtomicBoolean(false)
    private val captureLoopStarted = AtomicBoolean(false)
    private val selfClosing = AtomicBoolean(false)
    private val microphoneMuted = AtomicBoolean(false)
    private val speakerEnabled = AtomicBoolean(true)
    private val audioRouteAcquired = AtomicBoolean(false)

    private var webSocket: WebSocket? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var eventCallback: ((Event) -> Unit)? = null
    private var preparedCaptureSource: Int? = null
    private var preparedCaptureSampleRate: Int? = null
    private var captureConfigCursor = 0
    private var currentCallId: String? = null

    fun start(callId: String, onEvent: (Event) -> Unit) {
        stop("restart_before_start")
        currentCallId = callId
        eventCallback = onEvent
        running.set(true)
        captureLoopStarted.set(false)
        captureConfigCursor = 0
        AppFileLogger.i(TAG, "start callId=$callId")
        ioExecutor.execute {
            val request = Request.Builder()
                .url(buildWebSocketUrl(callId))
                .header("Authorization", "Bearer ${AccountIdentityProvider.accessToken}")
                .build()
            webSocket = httpClient.newWebSocket(request, SocketListener())
        }
    }

    fun stop(reason: String = "manual") {
        val existingSocket = webSocket
        webSocket = null
        running.set(false)
        connected.set(false)
        captureLoopStarted.set(false)
        AppFileLogger.i(
            TAG,
            "stop reason=$reason callId=${currentCallId.orEmpty()} " +
                "socketPresent=${existingSocket != null} routeAcquired=${audioRouteAcquired.get()}"
        )
        releaseCurrentAudioRecord()
        releasePlayback()
        if (existingSocket != null) {
            selfClosing.set(true)
            runCatching { existingSocket.close(1000, "client_closed") }
        }
        currentCallId = null
    }

    fun setMicrophoneMuted(enabled: Boolean) {
        microphoneMuted.set(enabled)
        AppFileLogger.i(TAG, "setMicrophoneMuted enabled=$enabled connected=${connected.get()}")
    }

    fun setSpeakerphoneEnabled(enabled: Boolean) {
        speakerEnabled.set(enabled)
        AppFileLogger.i(TAG, "setSpeakerphoneEnabled enabled=$enabled connected=${connected.get()}")
        if (running.get()) {
            updateAudioManagerForCall(enabled)
        }
    }

    private fun buildWebSocketUrl(callId: String): String {
        val base = BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/')
        return "$base/ws/assistant/translation-call/audio?callId=$callId"
    }

    private fun startAudioLoops(socket: WebSocket) {
        updateAudioManagerForCall(speakerEnabled.get())
        preparePlayback()
        startPreparedAudioCaptureLoop(socket)
    }

    private fun preparePlayback() {
        updateAudioManagerForCall(speakerEnabled.get())
        requestAudioFocus()
        val minTrackBuffer = AudioTrack.getMinBufferSize(
            TranslationCallAudioTargetSampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minTrackBuffer, TranslationCallAudioTargetSampleRate / 25)
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(TranslationCallAudioTargetSampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        runCatching { audioTrack?.play() }
    }

    private fun startPreparedAudioCaptureLoop(socket: WebSocket) {
        if (!captureLoopStarted.compareAndSet(false, true)) {
            return
        }
        ioExecutor.execute {
            while (running.get()) {
                val record = ensureCaptureReady()
                if (record == null) {
                    SystemClock.sleep(400L)
                    continue
                }
                val sampleRate = preparedCaptureSampleRate ?: TranslationCallAudioTargetSampleRate
                val buffer = ByteArray(TranslationCallAudioPcmPolicy.frameSizeBytes(sampleRate))
                while (running.get() && audioRecord === record) {
                    val count = readAudioRecord(record, buffer)
                    when {
                        count > 0 -> {
                            val pcm16k = TranslationCallAudioPcmPolicy.normalizeCaptureFrame(buffer, count, sampleRate)
                            val uplinkFrame = if (microphoneMuted.get()) {
                                ByteArray(pcm16k.size)
                            } else {
                                pcm16k
                            }
                            socket.send(uplinkFrame.toByteString())
                        }
                        count == 0 -> SystemClock.sleep(20L)
                        else -> {
                            emit(Event.Status(currentAppText("翻译电话麦克风读取异常，正在重试", "Translation microphone read failed. Retrying")))
                            advanceCaptureConfigCursor(preparedCaptureSource ?: -1, sampleRate)
                            releaseCurrentAudioRecord()
                            break
                        }
                    }
                }
            }
            captureLoopStarted.set(false)
        }
    }

    private fun ensureCaptureReady(): AudioRecord? {
        audioRecord?.let { return it }
        emit(Event.Status(currentAppText("正在准备翻译电话麦克风...", "Preparing translation microphone...")))
        val captureConfigs = TranslationCallAudioCaptureConfigPolicy.captureConfigs
        for (offset in captureConfigs.indices) {
            if (!running.get()) return null
            val config = captureConfigs[(captureConfigCursor + offset) % captureConfigs.size]
            val record = createAudioRecord(config.source, config.sampleRate)
            if (record != null) {
                audioRecord = record
                preparedCaptureSource = config.source
                preparedCaptureSampleRate = config.sampleRate
                captureConfigCursor = (captureConfigCursor + offset) % captureConfigs.size
                emit(Event.Status(currentAppText("翻译电话麦克风已就绪", "Translation microphone ready")))
                return record
            }
        }
        emit(Event.Status(currentAppText("翻译电话麦克风暂时不可用，正在重试...", "Translation microphone unavailable. Retrying...")))
        return null
    }

    private fun createAudioRecord(source: Int, sampleRate: Int): AudioRecord? {
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) return null
        val recordBuffer = maxOf(minBuffer, TranslationCallAudioPcmPolicy.frameSizeBytes(sampleRate) * 4)
        return runCatching {
            AudioRecord(
                source,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                recordBuffer
            )
        }.getOrNull()?.also { record ->
            val initialized = record.state == AudioRecord.STATE_INITIALIZED
            if (!initialized) {
                runCatching { record.release() }
                return null
            }
            val started = runCatching {
                record.startRecording()
                record.recordingState == AudioRecord.RECORDSTATE_RECORDING
            }.getOrDefault(false)
            if (!started) {
                runCatching {
                    record.stop()
                    record.release()
                }
                return null
            }
        }
    }

    private fun readAudioRecord(record: AudioRecord, buffer: ByteArray): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
        } else {
            record.read(buffer, 0, buffer.size)
        }
    }

    private fun advanceCaptureConfigCursor(source: Int, sampleRate: Int) {
        captureConfigCursor = TranslationCallAudioCaptureConfigPolicy.nextCursor(
            currentCursor = captureConfigCursor,
            source = source,
            sampleRate = sampleRate
        )
    }

    private fun releaseCurrentAudioRecord() {
        runCatching {
            audioRecord?.stop()
            audioRecord?.release()
        }
        audioRecord = null
        preparedCaptureSource = null
        preparedCaptureSampleRate = null
    }

    private fun releasePlayback() {
        runCatching {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.release()
        }
        audioTrack = null
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { request ->
                runCatching { audioManager.abandonAudioFocusRequest(request) }
            }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        releaseAudioManagerForCall()
    }

    private fun updateAudioManagerForCall(speakerphoneEnabled: Boolean) {
        if (!running.get()) {
            AppFileLogger.i(TAG, "skip audio route update while idle speakerphoneEnabled=$speakerphoneEnabled")
            return
        }
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = speakerphoneEnabled
        audioRouteAcquired.set(true)
    }

    private fun releaseAudioManagerForCall() {
        if (!audioRouteAcquired.getAndSet(false)) {
            AppFileLogger.i(TAG, "skip audio route release, route was not acquired")
            return
        }
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = false
    }

    private fun requestAudioFocus() {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        }
    }

    private fun emit(event: Event) {
        eventCallback?.invoke(event)
    }

    private inner class SocketListener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            runCatching { startAudioLoops(webSocket) }
                .onSuccess {
                    connected.set(true)
                    AppFileLogger.i(TAG, "websocket opened callId=${currentCallId.orEmpty()}")
                    emit(Event.Connected)
                    emit(Event.Status(currentAppText("翻译电话音频通道已连接", "Translation audio channel connected")))
                }
                .onFailure { throwable ->
                    AppFileLogger.w(TAG, "startAudioLoops failed", throwable)
                    stop("start_audio_loops_failed")
                    emit(Event.Error(throwable.message ?: "翻译电话音频初始化失败"))
                }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            emit(Event.Status(text))
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            val track = audioTrack ?: return
            val audioBytes = bytes.toByteArray()
            val playbackResult = runCatching {
                if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                    track.play()
                }
                track.write(audioBytes, 0, audioBytes.size)
            }
            playbackResult.onFailure { throwable ->
                AppFileLogger.w(TAG, "audio playback failed", throwable)
                emit(Event.Error(throwable.message ?: "缈昏瘧鐢佃瘽闊抽鎾斁澶辫触"))
                return
            }
            emit(Event.Status(currentAppText("已收到译后音频", "Translated audio received")))
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            AppFileLogger.i(TAG, "translation audio socket closing code=$code reason=$reason selfClosing=${selfClosing.get()}")
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            AppFileLogger.i(TAG, "translation audio socket closed code=$code reason=$reason selfClosing=${selfClosing.get()}")
            selfClosing.set(false)
            stop("websocket_closed:$code:$reason")
            emit(Event.Closed)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            AppFileLogger.w(TAG, "translation audio socket failed", t)
            selfClosing.set(false)
            stop("websocket_failure:${t.javaClass.simpleName}")
            emit(Event.Error(t.message ?: "翻译电话音频通道已断开"))
        }
    }
}
