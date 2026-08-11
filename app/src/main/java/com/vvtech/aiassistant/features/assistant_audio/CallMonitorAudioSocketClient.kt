package com.vvtech.aiassistant.features.assistant_audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRoute
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRouteState
import com.vvtech.aiassistant.logging.AppFileLogger
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString

/**
 * Read-only PCM16LE playback channel for monitoring an AI-controlled call.
 * This class intentionally never creates AudioRecord.
 */
class CallMonitorAudioSocketClient(private val context: Context) {

    sealed interface Event {
        object Connected : Event
        object Closed : Event
        data class Error(val message: String) : Event
        data class AudioRouteChanged(
            val state: CallMonitorAudioRouteState,
            val reason: String
        ) : Event
    }

    private val httpClient = OkHttpClient.Builder().build()
    private val routeManager = CallMonitorAudioRouteManager(context) { state, reason ->
        callback?.invoke(Event.AudioRouteChanged(state, reason))
    }
    private val running = AtomicBoolean(false)
    private val playbackEnabled = AtomicBoolean(false)
    private var socket: WebSocket? = null
    private var track: AudioTrack? = null
    private var callback: ((Event) -> Unit)? = null

    fun start(
        ticket: String,
        initialRoute: CallMonitorAudioRoute,
        onEvent: (Event) -> Unit
    ) {
        stop()
        callback = onEvent
        running.set(true)
        playbackEnabled.set(true)
        routeManager.start(initialRoute)
        prepareAudioTrack()
        val request = Request.Builder()
            .url(buildUrl())
            .header("X-Realtime-Ticket", ticket)
            .build()
        socket = httpClient.newWebSocket(request, Listener())
    }

    fun selectAudioRoute(route: CallMonitorAudioRoute) {
        routeManager.select(route)
    }

    fun setPlaybackEnabled(enabled: Boolean) {
        playbackEnabled.set(enabled)
        track?.let { audioTrack ->
            runCatching {
                if (enabled) {
                    if (audioTrack.playState != AudioTrack.PLAYSTATE_PLAYING) {
                        audioTrack.play()
                    }
                } else {
                    audioTrack.pause()
                    audioTrack.flush()
                }
            }
        }
    }

    fun stop() {
        running.set(false)
        socket?.close(1000, "done")
        socket = null
        runCatching {
            track?.pause()
            track?.flush()
            track?.release()
        }
        track = null
        routeManager.stop()
        callback = null
    }

    private fun buildUrl(): String {
        val base = BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/')
        return "$base/ws/assistant/call/monitor"
    }

    private fun prepareAudioTrack() {
        val minBuffer = AudioTrack.getMinBufferSize(
            16_000,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(16_000)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBuffer, 5_120))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            .also { it.play() }
    }

    private inner class Listener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            callback?.invoke(Event.Connected)
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            if (!running.get() || !playbackEnabled.get()) {
                return
            }
            val payload = bytes.toByteArray()
            val written = track?.write(payload, 0, payload.size) ?: -1
            if (written < 0) {
                AppFileLogger.w("CallMonitorAudio", "audioTrack write failed result=$written")
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (running.getAndSet(false)) {
                callback?.invoke(Event.Closed)
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (running.getAndSet(false)) {
                callback?.invoke(Event.Error(t.message ?: "监听通道已断开"))
            }
        }
    }
}
