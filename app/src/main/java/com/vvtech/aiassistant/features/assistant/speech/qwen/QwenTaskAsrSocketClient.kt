package com.vvtech.aiassistant.features.assistant.speech.qwen

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AudioEffect
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.vvtech.aiassistant.features.assistant.DefaultVoiceLanguageCode
import com.vvtech.aiassistant.features.assistant.TaskVoiceCloseReason
import com.vvtech.aiassistant.features.assistant.TaskVoiceAsrEvent
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_voice.TaskAsrClient
import com.vvtech.aiassistant.BuildConfig
import java.net.URLEncoder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import com.vvtech.aiassistant.account.AccountIdentityProvider
import okio.ByteString.Companion.toByteString
import org.json.JSONObject

internal class QwenTaskAsrSocketClient(
    context: Context
) : TaskAsrClient {
    private data class CaptureConfig(val source: Int, val sampleRate: Int)

    private val appContext = context.applicationContext
    private val httpClient = OkHttpClient.Builder().build()
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private val providerCaptureActive = AtomicBoolean(false)
    private val audioLoopStarted = AtomicBoolean(false)
    private val captureGenerationCounter = AtomicLong(0L)
    private val socketGenerationCounter = AtomicLong(0L)

    @Volatile private var webSocket: WebSocket? = null
    @Volatile private var audioRecord: AudioRecord? = null
    @Volatile private var callback: ((TaskVoiceAsrEvent) -> Unit)? = null
    @Volatile private var echoCanceler: AcousticEchoCanceler? = null
    @Volatile private var noiseSuppressor: NoiseSuppressor? = null
    @Volatile private var speechStarted = false
    @Volatile private var socketReady = false
    @Volatile private var socketConnecting = false
    @Volatile private var socketGeneration = 0L
    @Volatile private var currentLanguageCode = DefaultVoiceLanguageCode
    @Volatile private var acceptLateFinalGeneration = 0L
    @Volatile private var sentChunkCount = 0
    @Volatile private var sentAudioBytes = 0

    private val idleCloseRunnable = Runnable {
        closeSocketNow("idle_timeout")
    }

    override fun start(
        languageCode: String,
        startReason: String,
        onEvent: (TaskVoiceAsrEvent) -> Unit
    ) {
        val generation = captureGenerationCounter.incrementAndGet()
        mainHandler.removeCallbacks(idleCloseRunnable)
        pauseCapture()
        callback = onEvent
        currentLanguageCode = languageCode
        acceptLateFinalGeneration = 0L
        sentChunkCount = 0
        sentAudioBytes = 0
        running.set(true)
        speechStarted = false
        emit(generation, TaskVoiceAsrEvent.Connecting)
        val socket = webSocket
        if (socket != null && socketReady) {
            AppFileLogger.i(TAG, "VOICE_QWEN_TASK_ASR reuse socket reason=$startReason generation=$generation")
            emit(generation, TaskVoiceAsrEvent.Ready)
            beginProviderCapture(socket, generation)
            return
        }
        if (socket != null && socketConnecting) {
            AppFileLogger.i(TAG, "VOICE_QWEN_TASK_ASR await existing socket reason=$startReason generation=$generation")
            emit(generation, TaskVoiceAsrEvent.Status("语音识别连接中"))
            return
        }
        connectSocket(languageCode, startReason)
    }

    override fun stop() {
        captureGenerationCounter.incrementAndGet()
        acceptLateFinalGeneration = captureGenerationCounter.get()
        webSocket?.send(controlMessage("stop_capture", "reason" to "android_stop"))
        pauseCapture()
        scheduleIdleClose()
    }

    override fun release() = closeSocketNow("release")

    override fun closeNow(reason: String) = closeSocketNow(reason)

    private fun buildWebSocketUrl(languageCode: String): String {
        val base = BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/')
        val language = VoiceLanguage.fromCode(languageCode).code
        return "$base/ws/assistant/task-voice/asr" +
            "?languageCode=${URLEncoder.encode(language, "UTF-8")}"
    }

    private fun connectSocket(languageCode: String, startReason: String) {
        val generation = socketGenerationCounter.incrementAndGet()
        socketGeneration = generation
        socketReady = false
        socketConnecting = true
        AppFileLogger.i(TAG, "VOICE_QWEN_TASK_ASR connect reason=$startReason socketGeneration=$generation")
        val request = Request.Builder()
            .url(buildWebSocketUrl(languageCode))
            .header("Authorization", "Bearer ${AccountIdentityProvider.accessToken}")
            .build()
        webSocket = httpClient.newWebSocket(request, SocketListener(generation))
    }

    private fun beginProviderCapture(socket: WebSocket, generation: Long) {
        if (!isCurrent(generation) || !running.get()) {
            return
        }
        socket.send(
            controlMessage(
                "start_capture",
                "mode" to "open_listening"
            )
        )
        providerCaptureActive.set(true)
        startAudioLoopIfNeeded(generation)
    }

    private fun startAudioLoopIfNeeded(generation: Long) {
        if (!audioLoopStarted.compareAndSet(false, true)) {
            return
        }
        val record = createAudioRecord() ?: run {
            audioLoopStarted.set(false)
            if (running.get()) {
                emit(generation, TaskVoiceAsrEvent.Error("当前设备无法启动麦克风录音"))
            }
            return
        }
        audioRecord = record
        ioExecutor.execute {
            val buffer = ByteArray(FRAME_BYTES)
            while (running.get() && audioLoopStarted.get()) {
                val count = readAudio(record, buffer)
                if (count > 0) {
                    val socket = webSocket
                    if (running.get() && providerCaptureActive.get() && socket != null) {
                        recordSentAudio(count)
                        socket.send(buffer.copyOf(count).toByteString())
                    }
                } else if (count < 0) {
                    if (running.get()) {
                        emit(captureGenerationCounter.get(), TaskVoiceAsrEvent.Error("AudioRecord read failed: $count"))
                    }
                    break
                }
            }
        }
    }

    private fun createAudioRecord(): AudioRecord? {
        for (config in CAPTURE_CONFIGS) {
            val minBuffer = AudioRecord.getMinBufferSize(
                config.sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) continue
            val bufferSize = maxOf(minBuffer, FRAME_BYTES * 4)
            val record = runCatching {
                AudioRecord(
                    config.source,
                    config.sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize
                )
            }.getOrNull() ?: continue
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                runCatching { record.release() }
                continue
            }
            enableAudioEffects(record.audioSessionId)
            val started = runCatching {
                record.startRecording()
                record.recordingState == AudioRecord.RECORDSTATE_RECORDING
            }.getOrDefault(false)
            if (started) return record
            runCatching { record.stop() }
            runCatching { record.release() }
            releaseAudioEffects()
        }
        return null
    }

    private fun readAudio(record: AudioRecord, buffer: ByteArray): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
        } else {
            record.read(buffer, 0, buffer.size)
        }

    private fun pauseCapture() {
        running.set(false)
        providerCaptureActive.set(false)
        audioLoopStarted.set(false)
        releaseAudio()
    }

    private fun scheduleIdleClose() {
        mainHandler.removeCallbacks(idleCloseRunnable)
        if (webSocket != null) {
            mainHandler.postDelayed(idleCloseRunnable, IDLE_CLOSE_MS)
        }
    }

    private fun closeSocketNow(reason: String) {
        mainHandler.removeCallbacks(idleCloseRunnable)
        captureGenerationCounter.incrementAndGet()
        acceptLateFinalGeneration = 0L
        webSocket?.send(controlMessage("finish", "reason" to reason))
        pauseCapture()
        socketReady = false
        socketConnecting = false
        providerCaptureActive.set(false)
        socketGenerationCounter.incrementAndGet()
        socketGeneration = socketGenerationCounter.get()
        AppFileLogger.i(TAG, "VOICE_QWEN_TASK_ASR close reason=$reason")
        webSocket?.close(1000, reason)
        webSocket = null
    }

    private fun recordSentAudio(count: Int) {
        sentChunkCount += 1
        sentAudioBytes += count
    }

    private fun controlMessage(type: String, vararg fields: Pair<String, String>): String {
        val payload = JSONObject().put("type", type)
        fields.forEach { (key, value) -> payload.put(key, value) }
        return payload.toString()
    }

    private fun releaseAudio() {
        releaseAudioEffects()
        runCatching { audioRecord?.stop() }
        runCatching { audioRecord?.release() }
        audioRecord = null
    }

    private fun enableAudioEffects(audioSessionId: Int) {
        releaseAudioEffects()
        val aecAvailable = AcousticEchoCanceler.isAvailable()
        val nsAvailable = NoiseSuppressor.isAvailable()

        if (aecAvailable) {
            echoCanceler = runCatching {
                AcousticEchoCanceler.create(audioSessionId)?.apply { enabled = true }
            }.onFailure { throwable ->
                AppFileLogger.w(TAG, "VOICE_QWEN_TASK_ASR AEC enable failed: ${throwable.message}")
            }.getOrNull()
        }
        if (nsAvailable) {
            noiseSuppressor = runCatching {
                NoiseSuppressor.create(audioSessionId)?.apply { enabled = true }
            }.onFailure { throwable ->
                AppFileLogger.w(TAG, "VOICE_QWEN_TASK_ASR NS enable failed: ${throwable.message}")
            }.getOrNull()
        }
        AppFileLogger.i(
            TAG,
            "VOICE_QWEN_TASK_ASR audioEffects session=$audioSessionId " +
                "aecAvailable=$aecAvailable aecEnabled=${audioEffectEnabled(echoCanceler)} " +
                "nsAvailable=$nsAvailable nsEnabled=${audioEffectEnabled(noiseSuppressor)} " +
                "agcEnabled=false agcReason=disabled_to_avoid_noise_gain"
        )
    }

    private fun releaseAudioEffects() {
        runCatching { echoCanceler?.enabled = false }
        runCatching { noiseSuppressor?.enabled = false }
        runCatching { echoCanceler?.release() }
        runCatching { noiseSuppressor?.release() }
        echoCanceler = null
        noiseSuppressor = null
    }

    private fun audioEffectEnabled(effect: AudioEffect?): Boolean =
        runCatching { effect?.enabled == true }.getOrDefault(false)

    private fun isCurrent(generation: Long): Boolean = generation == captureGenerationCounter.get()

    private fun isCurrentSocket(generation: Long): Boolean = generation == socketGeneration

    private fun emit(generation: Long, event: TaskVoiceAsrEvent) {
        if (isCurrent(generation)) {
            callback?.invoke(event)
        }
    }

    private inner class SocketListener(private val generation: Long) : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            if (isCurrentSocket(generation)) {
                emit(captureGenerationCounter.get(), TaskVoiceAsrEvent.Status("语音识别连接中"))
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (!isCurrentSocket(generation)) return
            val payload = runCatching { JSONObject(text) }.getOrNull() ?: return
            when (payload.optString("type")) {
                "ready" -> {
                    socketReady = true
                    socketConnecting = false
                    val captureGeneration = captureGenerationCounter.get()
                    emit(captureGeneration, TaskVoiceAsrEvent.Ready)
                    if (running.get()) {
                        beginProviderCapture(webSocket, captureGeneration)
                    }
                }
                "status" -> payload.optString("message")
                    .takeIf { it.isNotBlank() }
                    ?.let { emit(captureGenerationCounter.get(), TaskVoiceAsrEvent.Status(it)) }
                "speech_started" -> speechStarted = true
                "speech_stopped" -> speechStarted = false
                "partial" -> emitTranscriptIfCaptureActive(payload.optString("text"), isFinal = false)
                "final" -> emitTranscriptIfCaptureActive(payload.optString("text"), isFinal = true)
                "error" -> emit(
                    captureGenerationCounter.get(),
                    TaskVoiceAsrEvent.Error(payload.optString("message").ifBlank { "语音识别失败" })
                )
            }
        }

        private fun emitTranscriptIfCaptureActive(text: String, isFinal: Boolean) {
            if (text.isBlank()) return
            if (!running.get() || !providerCaptureActive.get()) {
                if (isFinal && acceptLateFinalGeneration == captureGenerationCounter.get()) {
                    AppFileLogger.i(
                        TAG,
                        "VOICE_QWEN_TASK_ASR allow late final after stop text=${text.take(30)}"
                    )
                    acceptLateFinalGeneration = 0L
                } else {
                    AppFileLogger.i(
                        TAG,
                        "VOICE_QWEN_TASK_ASR drop ${if (isFinal) "final" else "partial"} while inactive text=${text.take(30)}"
                    )
                    return
                }
            }
            val event = if (isFinal) {
                TaskVoiceAsrEvent.FinalTranscript(text, turnId = null)
            } else {
                TaskVoiceAsrEvent.PartialTranscript(text, turnId = null)
            }
            emit(captureGenerationCounter.get(), event)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (isCurrentSocket(generation)) {
                socketReady = false
                socketConnecting = false
                this@QwenTaskAsrSocketClient.webSocket = null
                pauseCapture()
                emit(
                    captureGenerationCounter.get(),
                    TaskVoiceAsrEvent.Closed(reason.ifBlank { TaskVoiceCloseReason.ProviderClosed.logKey })
                )
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (isCurrentSocket(generation)) {
                socketReady = false
                socketConnecting = false
                this@QwenTaskAsrSocketClient.webSocket = null
                pauseCapture()
                emit(captureGenerationCounter.get(), TaskVoiceAsrEvent.Error(t.message ?: "语音识别通道异常"))
            }
        }
    }

    private companion object {
        private const val TAG = "QwenTaskAsrSocketClient"
        const val SAMPLE_RATE = 16_000
        const val FRAME_BYTES = 640
        const val IDLE_CLOSE_MS = 90_000L
        val CAPTURE_CONFIGS = listOf(
            CaptureConfig(MediaRecorder.AudioSource.VOICE_RECOGNITION, SAMPLE_RATE),
            CaptureConfig(MediaRecorder.AudioSource.MIC, SAMPLE_RATE)
        )
    }
}
