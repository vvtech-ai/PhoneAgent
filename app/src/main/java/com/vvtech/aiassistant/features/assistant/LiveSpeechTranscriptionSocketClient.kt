package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
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
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import okio.ByteString
import okio.ByteString.Companion.toByteString
import org.json.JSONObject

/**
 * Homepage speech-to-text tunnel.
 *
 * A generation id is attached to each websocket lifecycle so that stale
 * close/failure callbacks from the previous session cannot override the fresh
 * listening state after we auto-resume.
 */
class LiveSpeechTranscriptionSocketClient(
    private val context: Context
) {

    sealed interface Event {
        object Connected : Event
        object Ready : Event
        data class Status(val message: String) : Event
        data class PartialTranscript(val text: String) : Event
        data class FinalTranscript(val text: String) : Event
        data class Error(val message: String) : Event
        object Closed : Event
    }

    private val httpClient = OkHttpClient.Builder().build()
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private val audioLoopStarted = AtomicBoolean(false)
    private val generationCounter = AtomicLong(0L)
    private var webSocket: WebSocket? = null
    private var audioRecord: AudioRecord? = null
    private var eventCallback: ((Event) -> Unit)? = null

    fun start(
        userId: String,
        taskId: String?,
        languageCode: String = DefaultVoiceLanguageCode,
        onEvent: (Event) -> Unit
    ) {
        val generation = generationCounter.incrementAndGet()
        stopInternal(closeSocket = true)
        eventCallback = onEvent
        running.set(true)
        audioLoopStarted.set(false)
        val request = Request.Builder()
            .url(buildWebSocketUrl(userId, taskId, languageCode))
            .header("Authorization", "Bearer ${AccountIdentityProvider.accessToken}")
            .build()
        webSocket = httpClient.newWebSocket(request, SocketListener(generation))
    }

    fun stop() {
        generationCounter.incrementAndGet()
        stopInternal(closeSocket = true)
    }

    fun release() {
        stop()
    }

    private fun buildWebSocketUrl(userId: String, taskId: String?, languageCode: String): String {
        val base = BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/')
        val normalizedLanguageCode = VoiceLanguage.fromCode(languageCode).code
        val queryParts = buildList {
            add("userId=${encodeQueryValue(userId)}")
            if (!taskId.isNullOrBlank()) add("taskId=${encodeQueryValue(taskId)}")
            add("languageCode=${encodeQueryValue(normalizedLanguageCode)}")
        }
        return "$base/ws/assistant/realtime/transcription?" + queryParts.joinToString("&")
    }

    private fun encodeQueryValue(value: String): String = URLEncoder.encode(value, "UTF-8")

    private fun startAudioLoopIfNeeded(socket: WebSocket, generation: Long) {
        if (!isCurrent(generation) || !running.get() || !audioLoopStarted.compareAndSet(false, true)) {
            return
        }
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        val sampleRate = 16_000
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuffer, 640 * 4)
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        ).apply { startRecording() }

        ioExecutor.execute {
            val buffer = ByteArray(640)
            while (running.get() && isCurrent(generation) && audioLoopStarted.get()) {
                val count = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (count > 0) {
                    socket.send(buffer.copyOf(count).toByteString())
                }
            }
        }
    }

    private fun stopInternal(closeSocket: Boolean) {
        running.set(false)
        audioLoopStarted.set(false)
        releaseAudio()
        if (closeSocket) {
            webSocket?.close(1000, "done")
        }
        webSocket = null
    }

    private fun releaseAudio() {
        runCatching {
            audioRecord?.stop()
            audioRecord?.release()
        }
        audioRecord = null
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    private fun isCurrent(generation: Long): Boolean = generation == generationCounter.get()

    private fun emit(generation: Long, event: Event) {
        if (isCurrent(generation)) {
            eventCallback?.invoke(event)
        }
    }

    private inner class SocketListener(
        private val generation: Long
    ) : WebSocketListener() {

        override fun onOpen(webSocket: WebSocket, response: Response) {
            emit(generation, Event.Connected)
            emit(generation, Event.Status(currentAppText("正在连接实时转写...", "Connecting transcription...")))
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (!isCurrent(generation)) return
            val payload = runCatching { JSONObject(text) }.getOrNull() ?: return
            when (payload.optString("type")) {
                "ready" -> {
                    emit(generation, Event.Ready)
                    emit(
                        generation,
                        Event.Status(
                            localizedLiveSpeechMessage(
                                payload.optString("message").ifBlank {
                                    currentAppText("正在听你说...", "Listening...")
                                }
                            )
                        )
                    )
                    startAudioLoopIfNeeded(webSocket, generation)
                }

                "status" -> {
                    payload.optString("message")
                        .takeIf { it.isNotBlank() }
                        ?.let { emit(generation, Event.Status(localizedLiveSpeechMessage(it))) }
                }

                "partial" -> {
                    payload.optString("text")
                        .takeIf { it.isNotBlank() }
                        ?.let { emit(generation, Event.PartialTranscript(it)) }
                }

                "final" -> {
                    payload.optString("text")
                        .takeIf { it.isNotBlank() }
                        ?.let { emit(generation, Event.FinalTranscript(it)) }
                }

                "error" -> {
                    emit(
                        generation,
                        Event.Error(
                            localizedLiveSpeechMessage(
                                payload.optString("message").ifBlank {
                                    currentAppText("实时转写服务异常", "Live transcription service error")
                                }
                            )
                        )
                    )
                }
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            if (isCurrent(generation)) {
                stopInternal(closeSocket = false)
                emit(generation, Event.Closed)
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (isCurrent(generation)) {
                stopInternal(closeSocket = false)
                emit(generation, Event.Closed)
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (isCurrent(generation)) {
                stopInternal(closeSocket = false)
                emit(
                    generation,
                    Event.Error(
                        localizedLiveSpeechMessage(
                            t.message ?: currentAppText("实时转写通道异常", "Live transcription channel error")
                        )
                    )
                )
            }
        }
    }

    private fun localizedLiveSpeechMessage(message: String): String {
        val language = if (currentAppText("中文", "English") == "English") {
            VoiceLanguage.English
        } else {
            VoiceLanguage.Chinese
        }
        return sanitizeUserFacingNetworkText(message, language)
    }
}
