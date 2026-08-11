package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_audio.TakeoverAudioCaptureConfigPolicy
import com.vvtech.aiassistant.features.assistant_audio.TakeoverAudioPcmPolicy
import com.vvtech.aiassistant.features.assistant_audio.TakeoverAudioTargetFrameSizeBytes
import com.vvtech.aiassistant.features.assistant_audio.TakeoverAudioTargetSampleRate
import com.vvtech.aiassistant.logging.AppFileLogger

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
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import com.vvtech.aiassistant.account.AccountIdentityProvider
import okio.ByteString
import okio.ByteString.Companion.toByteString

private const val TAG = "TakeoverAudioSocket"

/**
 * App <-> backend raw PCM audio tunnel used for manual call takeover.
 */
class TakeoverAudioSocketClient(private val context: Context) {

    sealed interface Event {
        data class Status(val message: String) : Event
        data class Error(val message: String) : Event
        object Connected : Event
        object Closed : Event
    }

    private val httpClient = OkHttpClient.Builder().build()
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private val playbackEnabled = AtomicBoolean(true)
    private val captureEnabled = AtomicBoolean(true)
    private val speakerEnabled = AtomicBoolean(true)
    private val connected = AtomicBoolean(false)
    private val selfClosing = AtomicBoolean(false)
    private val remoteAudioReceived = AtomicBoolean(false)
    private val remoteAudioPlayed = AtomicBoolean(false)
    private val captureLoopStarted = AtomicBoolean(false)
    private val takeoverReadyEmitted = AtomicBoolean(false)

    private var webSocket: WebSocket? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var eventCallback: ((Event) -> Unit)? = null
    private var preparedCaptureSource: Int? = null
    private var preparedCaptureSampleRate: Int? = null
    private var captureConfigCursor = 0

    fun start(taskId: String?, callId: String?, onEvent: (Event) -> Unit) {
        stop()
        eventCallback = onEvent
        playbackEnabled.set(true)
        captureEnabled.set(true)
        speakerEnabled.set(true)
        selfClosing.set(false)
        remoteAudioReceived.set(false)
        remoteAudioPlayed.set(false)
        takeoverReadyEmitted.set(false)
        captureConfigCursor = 0
        running.set(true)
        ioExecutor.execute {
            openSocket(taskId, callId)
        }
    }

    fun stop() {
        stopInternal(closeSocket = true, emitClosed = false)
    }

    fun release() {
        stop()
    }

    fun setPlaybackEnabled(enabled: Boolean) {
        playbackEnabled.set(enabled)
        AppFileLogger.i(TAG, "setPlaybackEnabled enabled=$enabled connected=${connected.get()}")
        audioTrack?.let { track ->
            runCatching {
                if (enabled) {
                    if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                        track.play()
                    }
                } else {
                    track.pause()
                    track.flush()
                }
            }
        }
    }

    fun setSpeakerphoneEnabled(enabled: Boolean) {
        speakerEnabled.set(enabled)
        AppFileLogger.i(TAG, "setSpeakerphoneEnabled enabled=$enabled connected=${connected.get()}")
        updateAudioManagerForCall(enabled)
    }

    fun setCaptureEnabled(enabled: Boolean) {
        captureEnabled.set(enabled)
        AppFileLogger.i(TAG, "setCaptureEnabled enabled=$enabled connected=${connected.get()}")
    }

    fun isConnected(): Boolean = connected.get()

    private fun buildWebSocketUrl(taskId: String?, callId: String?): String {
        val base = BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/')
        val queryParts = buildList {
            if (!taskId.isNullOrBlank()) add("taskId=$taskId")
            if (!callId.isNullOrBlank()) add("callId=$callId")
        }
        val query = if (queryParts.isEmpty()) "" else "?" + queryParts.joinToString("&")
        return "$base/ws/assistant/call/takeover$query"
    }

    private fun openSocket(taskId: String?, callId: String?) {
        val url = buildWebSocketUrl(taskId, callId)
        AppFileLogger.i(TAG, "start callId=$callId taskId=$taskId endpointConfigured=${url.isNotBlank()}")
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer ${AccountIdentityProvider.accessToken}")
            .build()
        webSocket = httpClient.newWebSocket(request, SocketListener())
    }

    private fun startAudioLoops(socket: WebSocket) {
        updateAudioManagerForCall(speakerEnabled.get())
        sendClientStatus(socket, "ws_open")
        prepareAudioPlayback()
        startPreparedAudioCaptureLoop(socket)
    }

    private fun sendClientStatus(socket: WebSocket, message: String) {
        val payload = "status:$message"
        AppFileLogger.i(TAG, "client status -> $payload")
        runCatching { socket.send(payload) }
    }

    private fun prepareAudioPlayback() {
        updateAudioManagerForCall(speakerEnabled.get())
        requestAudioFocus()
        val minTrackBuffer = AudioTrack.getMinBufferSize(
            TakeoverAudioTargetSampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minTrackBuffer, TakeoverAudioTargetFrameSizeBytes * 8)
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(TakeoverAudioTargetSampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        audioTrack?.apply {
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setVolume(1.0f)
                } else {
                    @Suppress("DEPRECATION")
                    setStereoVolume(1.0f, 1.0f)
                }
            }
            if (playbackEnabled.get() && playState != AudioTrack.PLAYSTATE_PLAYING) {
                play()
            }
            AppFileLogger.i(
                TAG,
                "audioTrack ready sessionId=$audioSessionId playState=$playState state=$state buffer=$bufferSize"
            )
        }
        emit(Event.Status("人工接管声音已就绪"))
    }

    private fun startPreparedAudioCaptureLoop(socket: WebSocket) {
        if (!captureLoopStarted.compareAndSet(false, true)) {
            return
        }
        ioExecutor.execute {
            while (running.get()) {
                val record = ensureCaptureReady(socket)
                if (record == null) {
                    Thread.sleep(500L)
                    continue
                }
                val source = preparedCaptureSource ?: -1
                val sampleRate = preparedCaptureSampleRate ?: TakeoverAudioTargetSampleRate
                val buffer = ByteArray(TakeoverAudioPcmPolicy.frameSizeBytes(sampleRate))
                val silence = ByteArray(TakeoverAudioTargetFrameSizeBytes)
                var zeroReadCount = 0
                var sentSyntheticUplink = false
                var zeroReadStartedAt = 0L
                while (running.get() && audioRecord === record) {
                    val count = readAudioRecord(record, buffer)
                    when {
                        count > 0 -> {
                            zeroReadCount = 0
                            zeroReadStartedAt = 0L
                            if (!sentSyntheticUplink) {
                                sendClientStatus(socket, "capture_first_pcm:$count")
                            }
                            sentSyntheticUplink = true
                            val pcm16k = if (captureEnabled.get()) {
                                TakeoverAudioPcmPolicy.normalizeCaptureFrame(buffer, count, sampleRate)
                            } else {
                                silence
                            }
                            socket.send(pcm16k.toByteString())
                        }
                        count == 0 -> {
                            if (zeroReadStartedAt == 0L) {
                                zeroReadStartedAt = SystemClock.elapsedRealtime()
                            }
                            zeroReadCount++
                            if (!sentSyntheticUplink) {
                                sentSyntheticUplink = true
                                AppFileLogger.i(TAG, "audioRecord produced no data yet; sending initial silence uplink")
                                sendClientStatus(socket, "capture_zero_send_silence")
                                socket.send(silence.toByteString())
                            }
                            if (zeroReadCount == 10 || zeroReadCount == 20 || zeroReadCount == 40) {
                                sendClientStatus(socket, "capture_zero_read:$zeroReadCount")
                            }
                            if (SystemClock.elapsedRealtime() - zeroReadStartedAt >= 1_500L) {
                                sendClientStatus(socket, "capture_restart_after_stall:$source")
                                emit(Event.Status("人工接管麦克风启动较慢，正在重试..."))
                                advanceCaptureConfigCursor(source, sampleRate)
                                releaseCurrentAudioRecord()
                                break
                            }
                            SystemClock.sleep(20L)
                        }
                        count < 0 -> {
                            AppFileLogger.w(TAG, "audioRecord read error code=$count source=$source rate=$sampleRate")
                            sendClientStatus(socket, "capture_error:$count")
                            emit(Event.Status("人工接管麦克风读取异常，正在重试..."))
                            advanceCaptureConfigCursor(source, sampleRate)
                            releaseCurrentAudioRecord()
                            break
                        }
                    }
                }
            }
            captureLoopStarted.set(false)
        }
    }

    private fun ensureCaptureReady(socket: WebSocket): AudioRecord? {
        audioRecord?.let { return it }
        sendClientStatus(socket, "capture_waiting")
        emit(Event.Status("正在准备人工接管麦克风..."))
        val configs = TakeoverAudioCaptureConfigPolicy.captureConfigs
        for (offset in configs.indices) {
            val config = configs[(captureConfigCursor + offset) % configs.size]
            if (!running.get()) {
                return null
            }
            val record = createAudioRecord(config.source, config.sampleRate)
            if (record != null) {
                audioRecord = record
                preparedCaptureSource = config.source
                preparedCaptureSampleRate = config.sampleRate
                captureConfigCursor = (captureConfigCursor + offset) % configs.size
                sendClientStatus(socket, "capture_ready:${config.source}:${config.sampleRate}")
                sendClientStatus(socket, "takeover_ready:${config.source}:${config.sampleRate}")
                if (takeoverReadyEmitted.compareAndSet(false, true)) {
                    emit(Event.Connected)
                }
                emit(Event.Status("人工接管麦克风已就绪"))
                return record
            }
            sendClientStatus(socket, "capture_source_failed:${config.source}:${config.sampleRate}")
        }
        emit(Event.Status("人工接管麦克风暂时不可用，正在重试..."))
        return null
    }

    private fun readAudioRecord(record: AudioRecord, buffer: ByteArray): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
        } else {
            record.read(buffer, 0, buffer.size)
        }
    }

    private fun createAudioRecord(source: Int, sampleRate: Int): AudioRecord? {
        val minRecordBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minRecordBuffer <= 0) {
            AppFileLogger.w(TAG, "createAudioRecord invalid min buffer source=$source rate=$sampleRate min=$minRecordBuffer")
            return null
        }
        val recordBuffer = maxOf(minRecordBuffer, TakeoverAudioPcmPolicy.frameSizeBytes(sampleRate) * 4)
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
                AppFileLogger.w(TAG, "audioRecord not initialized source=$source rate=$sampleRate")
                runCatching { record.release() }
                return null
            }
            val started = runCatching {
                record.startRecording()
                record.recordingState == AudioRecord.RECORDSTATE_RECORDING
            }.getOrDefault(false)
            if (!started) {
                AppFileLogger.w(TAG, "audioRecord start failed source=$source rate=$sampleRate")
                runCatching {
                    record.stop()
                    record.release()
                }
                return null
            }
            AppFileLogger.i(TAG, "audioRecord ready source=$source sampleRate=$sampleRate buffer=$recordBuffer")
        }
    }

    private fun stopInternal(closeSocket: Boolean, emitClosed: Boolean) {
        val existingSocket = webSocket
        webSocket = null
        running.set(false)
        connected.set(false)
        captureLoopStarted.set(false)
        releaseAudio()
        if (closeSocket && existingSocket != null) {
            selfClosing.set(true)
            runCatching { existingSocket.close(1000, "done") }
        }
        if (emitClosed) {
            emit(Event.Closed)
        }
    }

    private fun releaseAudio() {
        releaseCurrentAudioRecord()
        runCatching {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.release()
        }
        audioTrack = null
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        abandonAudioFocus(audioManager)
        audioManager.isSpeakerphoneOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
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

    private fun advanceCaptureConfigCursor(source: Int, sampleRate: Int) {
        captureConfigCursor = TakeoverAudioCaptureConfigPolicy.nextCursor(captureConfigCursor, source, sampleRate)
        AppFileLogger.i(TAG, "advance capture config cursor -> $captureConfigCursor after source=$source rate=$sampleRate")
    }

    private fun updateAudioManagerForCall(speakerphoneEnabled: Boolean) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = if (running.get()) {
            AudioManager.MODE_IN_COMMUNICATION
        } else {
            AudioManager.MODE_NORMAL
        }
        audioManager.isSpeakerphoneOn = speakerphoneEnabled
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

    private fun abandonAudioFocus(audioManager: AudioManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { request ->
                runCatching { audioManager.abandonAudioFocusRequest(request) }
            }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
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
                    emit(Event.Status("人工接管音频通道已连接，正在准备麦克风"))
                }
                .onFailure { throwable ->
                    AppFileLogger.w(TAG, "startAudioLoops failed message=${throwable.message}", throwable)
                    sendClientStatus(webSocket, "start_audio_loops_failed:${throwable.message ?: "unknown"}")
                    stopInternal(closeSocket = true, emitClosed = false)
                    emit(Event.Error(throwable.message ?: "人工接管音频初始化失败"))
                }
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            if (!playbackEnabled.get()) {
                return
            }
            if (remoteAudioReceived.compareAndSet(false, true)) {
                AppFileLogger.i(TAG, "received first remote audio packet bytes=${bytes.size}")
                emit(Event.Status("已收到对方语音"))
            }
            val audioBytes = bytes.toByteArray()
            audioTrack?.let { track ->
                if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                    runCatching { track.play() }
                }
                val written = track.write(audioBytes, 0, audioBytes.size)
                if (remoteAudioPlayed.compareAndSet(false, true)) {
                    AppFileLogger.i(TAG, "first audio write result=$written bytes=${audioBytes.size} playState=${track.playState}")
                }
                if (written < 0) {
                    AppFileLogger.w(TAG, "audioTrack write failed result=$written bytes=${audioBytes.size}")
                }
            } ?: AppFileLogger.w(TAG, "audioTrack missing when remote audio arrived bytes=${audioBytes.size}")
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            AppFileLogger.i(TAG, "socket onClosing code=$code reason=$reason selfClosing=${selfClosing.get()}")
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            AppFileLogger.i(TAG, "socket onClosed code=$code reason=$reason selfClosing=${selfClosing.get()}")
            selfClosing.set(false)
            stopInternal(closeSocket = false, emitClosed = true)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            AppFileLogger.w(TAG, "socket onFailure message=${t.message}", t)
            selfClosing.set(false)
            stopInternal(closeSocket = false, emitClosed = false)
            emit(Event.Error(t.message ?: "人工接管音频通道已断开"))
        }
    }
}
