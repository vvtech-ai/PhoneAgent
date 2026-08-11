package com.vvtech.aiassistant.features.assistant.speech.qwen

import com.vvtech.aiassistant.logging.AppFileLogger

import android.os.Handler
import android.os.Looper
import com.vvtech.aiassistant.features.assistant.speech.DEFAULT_TTS_SPEAKER
import com.vvtech.aiassistant.features.assistant.speech.TtsApiClient
import com.vvtech.aiassistant.features.assistant.speech.TtsAudioFormat
import com.vvtech.aiassistant.features.assistant.stripMarkdownForTts
import com.vvtech.aiassistant.BuildConfig
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import com.vvtech.aiassistant.account.AccountIdentityProvider
import okio.ByteString
import org.json.JSONObject

class QwenTaskTtsApiClient(
    private val socketFactory: ((Request, WebSocketListener) -> WebSocket)? = null,
    private val delayScheduler: QwenTaskTtsDelayScheduler = AndroidQwenTaskTtsDelayScheduler(),
    private val logSink: QwenTaskTtsLogSink = AndroidQwenTaskTtsLogSink
) : TtsApiClient {

    override val audioFormat: TtsAudioFormat = TtsAudioFormat.Pcm24k16BitMono

    private class PendingSynthesis(
        val generation: Long,
        val text: String,
        val speaker: String,
        val continuation: CancellableContinuation<Unit>,
        val onAudioChunk: (ByteArray) -> Unit,
        val onComplete: () -> Unit,
        val onError: (Throwable) -> Unit
    ) {
        val audioBuffer = ByteArrayOutputStream()
        var firstAudioTimeout: Runnable? = null
        var completeTimeout: Runnable? = null
        var streamingStarted = false
        var firstAudioReceived = false
        var receivedBytes = 0
        var emittedBytes = 0
        var sendStarted = false
        var completed = false
    }

    private val httpClient = OkHttpClient.Builder().build()
    private val activeSocket = AtomicReference<WebSocket?>()
    private val activeGeneration = AtomicLong(0L)
    private val socketGenerationCounter = AtomicLong(0L)
    private val lock = Any()

    @Volatile private var socketGeneration = 0L
    @Volatile private var socketReady = false
    @Volatile private var socketConnecting = false
    @Volatile private var pending: PendingSynthesis? = null

    private val idleCloseRunnable = Runnable {
        closeSocketNow("idle_timeout")
    }

    override suspend fun synthesize(
        text: String,
        speaker: String,
        onAudioChunk: (ByteArray) -> Unit,
        onComplete: () -> Unit,
        onError: (Throwable) -> Unit
    ) {
        val sanitized = stripMarkdownForTts(text)
        if (sanitized.isBlank()) {
            onComplete()
            return
        }
        return suspendCancellableCoroutine { continuation ->
            val generation = activeGeneration.incrementAndGet()
            val pendingSynthesis = PendingSynthesis(
                generation = generation,
                text = sanitized,
                speaker = speaker.ifBlank { DEFAULT_TTS_SPEAKER },
                continuation = continuation,
                onAudioChunk = onAudioChunk,
                onComplete = onComplete,
                onError = onError
            )
            val socket = synchronized(lock) {
                delayScheduler.removeCallbacks(idleCloseRunnable)
                pending?.let { previous ->
                    previous.audioBuffer.reset()
                    previous.completed = true
                    if (previous.continuation.isActive) {
                        previous.continuation.resume(Unit)
                    }
                }
                pending = pendingSynthesis
                ensureSocketLocked()
            }
            scheduleSynthesisTimeouts(pendingSynthesis)
            sendPendingIfReady(socket)
            continuation.invokeOnCancellation {
                cancelGeneration(generation)
            }
        }
    }

    override fun cancel() {
        cancelGeneration(activeGeneration.incrementAndGet())
    }

    fun closeNow(reason: String = "manual") {
        closeSocketNow(reason)
    }

    override fun close(reason: String) {
        closeSocketNow(reason)
    }

    private fun ensureSocketLocked(): WebSocket {
        activeSocket.get()?.let { return it }
        val generation = socketGenerationCounter.incrementAndGet()
        socketGeneration = generation
        socketReady = false
        socketConnecting = true
        logSink.i(TAG, "TTS_DIAG qwen connect socketGeneration=$generation")
        val request = Request.Builder()
            .url(buildTtsUrl())
            .header("Authorization", "Bearer ${AccountIdentityProvider.accessToken}")
            .build()
        val listener = SocketListener(generation)
        return (socketFactory?.invoke(request, listener) ?: httpClient.newWebSocket(request, listener))
            .also { activeSocket.set(it) }
    }

    private fun sendPendingIfReady(webSocket: WebSocket?) {
        if (webSocket == null) return
        val payload = synchronized(lock) {
            val current = pending ?: return
            if (!socketReady || current.sendStarted || activeSocket.get() !== webSocket) {
                return
            }
            current.sendStarted = true
            JSONObject()
                .put("type", "synthesize")
                .put("text", current.text)
                .put("speaker", current.speaker)
                .toString()
        }
        webSocket.send(payload)
    }

    private fun appendAndMaybeDrainAudio(webSocket: WebSocket, bytes: ByteArray): Pair<PendingSynthesis, ByteArray>? =
        synchronized(lock) {
            val current = pending ?: return@synchronized null
            if (activeSocket.get() !== webSocket || activeGeneration.get() != current.generation || current.completed) {
                return@synchronized null
            }
            markFirstAudioReceivedLocked(current)
            current.receivedBytes += bytes.size
            current.audioBuffer.write(bytes)
            val threshold = if (current.streamingStarted) QWEN_TTS_STREAM_CHUNK_BYTES else QWEN_TTS_PREBUFFER_BYTES
            if (current.audioBuffer.size() < threshold) {
                return@synchronized null
            }
            current.streamingStarted = true
            val chunk = drainBufferedAudioLocked(current) ?: return@synchronized null
            current to chunk
        }

    private fun completePending(webSocket: WebSocket): Pair<PendingSynthesis, ByteArray?>? =
        synchronized(lock) {
            val current = pending ?: return@synchronized null
            if (activeSocket.get() !== webSocket || activeGeneration.get() != current.generation || current.completed) {
                return@synchronized null
            }
            current.streamingStarted = true
            val remaining = drainBufferedAudioLocked(current)
            current.completed = true
            pending = null
            cancelSynthesisTimeoutsLocked(current)
            scheduleIdleCloseLocked()
            current to remaining
        }

    private fun failPending(webSocket: WebSocket?, throwable: Throwable) {
        val current = synchronized(lock) {
            val active = pending
            if (webSocket != null && activeSocket.get() !== webSocket) {
                return
            }
            active?.audioBuffer?.reset()
            active?.completed = true
            pending = null
            active?.let { cancelSynthesisTimeoutsLocked(it) }
            scheduleIdleCloseLocked()
            active
        } ?: return
        current.onError(throwable)
        if (current.continuation.isActive) {
            current.continuation.resume(Unit)
        }
    }

    private fun cancelGeneration(generation: Long) {
        val socket: WebSocket?
        val current: PendingSynthesis?
        synchronized(lock) {
            current = pending?.takeIf { it.generation <= generation }
            current?.audioBuffer?.reset()
            current?.completed = true
            current?.let { cancelSynthesisTimeoutsLocked(it) }
            if (current != null) {
                pending = null
            }
            socket = activeSocket.get()
            scheduleIdleCloseLocked()
        }
        socket?.send(JSONObject().put("type", "cancel").toString())
        if (current?.continuation?.isActive == true) {
            current.continuation.resume(Unit)
        }
    }

    private fun drainBufferedAudioLocked(current: PendingSynthesis): ByteArray? {
        if (current.audioBuffer.size() <= 0) return null
        val bytes = current.audioBuffer.toByteArray()
        current.audioBuffer.reset()
        current.emittedBytes += bytes.size
        return bytes
    }

    private fun scheduleIdleCloseLocked() {
        delayScheduler.removeCallbacks(idleCloseRunnable)
        if (pending == null && activeSocket.get() != null) {
            delayScheduler.postDelayed(idleCloseRunnable, IDLE_CLOSE_MS)
        }
    }

    private fun closeSocketNow(reason: String) {
        val socket: WebSocket?
        val current: PendingSynthesis?
        synchronized(lock) {
            delayScheduler.removeCallbacks(idleCloseRunnable)
            current = pending
            current?.audioBuffer?.reset()
            current?.completed = true
            current?.let { cancelSynthesisTimeoutsLocked(it) }
            pending = null
            socketReady = false
            socketConnecting = false
            socketGeneration = socketGenerationCounter.incrementAndGet()
            socket = activeSocket.getAndSet(null)
        }
        logSink.i(TAG, "TTS_DIAG qwen close reason=$reason")
        socket?.close(1000, reason)
        if (current?.continuation?.isActive == true) {
            current.continuation.resume(Unit)
        }
    }

    private fun scheduleSynthesisTimeouts(current: PendingSynthesis) {
        val firstAudioTimeout = Runnable {
            timeoutPendingWithSoftCompletion(current.generation, "first_audio_timeout")
        }
        val completeTimeout = Runnable {
            timeoutPendingWithSoftCompletion(current.generation, "completion_timeout")
        }
        synchronized(lock) {
            if (pending !== current || current.completed) {
                return
            }
            current.firstAudioTimeout = firstAudioTimeout
            current.completeTimeout = completeTimeout
        }
        delayScheduler.postDelayed(firstAudioTimeout, FIRST_AUDIO_TIMEOUT_MS)
        delayScheduler.postDelayed(completeTimeout, completionTimeoutMillisFor(current.text))
    }

    private fun markFirstAudioReceivedLocked(current: PendingSynthesis) {
        if (current.firstAudioReceived) return
        current.firstAudioReceived = true
        current.firstAudioTimeout?.let(delayScheduler::removeCallbacks)
        current.firstAudioTimeout = null
    }

    private fun cancelSynthesisTimeoutsLocked(current: PendingSynthesis) {
        current.firstAudioTimeout?.let(delayScheduler::removeCallbacks)
        current.completeTimeout?.let(delayScheduler::removeCallbacks)
        current.firstAudioTimeout = null
        current.completeTimeout = null
    }

    private fun timeoutPendingWithSoftCompletion(generation: Long, reason: String) {
        val timeoutState = synchronized(lock) {
            val current = pending?.takeIf { it.generation == generation && !it.completed }
                ?: return
            current.completed = true
            cancelSynthesisTimeoutsLocked(current)
            pending = null
            socketReady = false
            socketConnecting = false
            socketGeneration = socketGenerationCounter.incrementAndGet()
            val socket = activeSocket.getAndSet(null)
            if (reason == "completion_timeout" && current.receivedBytes > 0) {
                TimeoutResult.SoftComplete(
                    current = current,
                    socket = socket,
                    remaining = drainBufferedAudioLocked(current)
                )
            } else {
                current.audioBuffer.reset()
                TimeoutResult.Error(current = current, socket = socket)
            }
        }
        when (timeoutState) {
            is TimeoutResult.SoftComplete -> {
                val current = timeoutState.current
                logSink.i(
                    TAG,
                    "TTS_DIAG qwen softCompleteOnTimeout generation=$generation reason=$reason " +
                        "receivedBytes=${current.receivedBytes} emittedBytes=${current.emittedBytes}"
                )
                timeoutState.socket?.close(1000, reason)
                timeoutState.remaining?.let { current.onAudioChunk(it) }
                current.onComplete()
                if (current.continuation.isActive) {
                    current.continuation.resume(Unit)
                }
            }

            is TimeoutResult.Error -> {
                val current = timeoutState.current
                logSink.i(TAG, "TTS_DIAG qwen timeout generation=$generation reason=$reason")
                timeoutState.socket?.close(1000, reason)
                current.onError(IllegalStateException("voice tts failed: $reason"))
                if (current.continuation.isActive) {
                    current.continuation.resume(Unit)
                }
            }
        }
    }

    private sealed class TimeoutResult {
        data class SoftComplete(
            val current: PendingSynthesis,
            val socket: WebSocket?,
            val remaining: ByteArray?
        ) : TimeoutResult()

        data class Error(
            val current: PendingSynthesis,
            val socket: WebSocket?
        ) : TimeoutResult()
    }

    private fun completionTimeoutMillisFor(text: String): Long {
        val estimated = text.trim().length * SYNTHESIS_COMPLETE_TIMEOUT_PER_CHAR_MS
        return estimated.coerceIn(MIN_SYNTHESIS_COMPLETE_TIMEOUT_MS, MAX_SYNTHESIS_COMPLETE_TIMEOUT_MS)
    }

    private fun buildTtsUrl(): String {
        val base = BuildConfig.BASE_URL
            .replaceFirst("http://", "ws://")
            .replaceFirst("https://", "wss://")
            .trimEnd('/')
        return "$base/ws/assistant/task-voice/tts"
    }

    private inner class SocketListener(private val generation: Long) : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            if (generation == socketGeneration) {
                logSink.i(TAG, "TTS_DIAG qwen socketOpen generation=$generation")
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (generation != socketGeneration) return
            val payload = runCatching { JSONObject(text) }.getOrNull() ?: return
            when (payload.optString("type")) {
                "ready" -> {
                    synchronized(lock) {
                        socketReady = true
                        socketConnecting = false
                    }
                    sendPendingIfReady(webSocket)
                }

                "complete" -> {
                    completePending(webSocket)?.let { (current, remaining) ->
                        remaining?.let { current.onAudioChunk(it) }
                        logSink.i(
                            TAG,
                            "TTS_DIAG qwen complete generation=${current.generation} " +
                                "receivedBytes=${current.receivedBytes} emittedBytes=${current.emittedBytes}"
                        )
                        current.onComplete()
                        if (current.continuation.isActive) {
                            current.continuation.resume(Unit)
                        }
                    }
                }

                "error" -> {
                    failPending(
                        webSocket,
                        IllegalStateException(payload.optString("message").ifBlank { "语音播报失败" })
                    )
                }
            }
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            if (generation != socketGeneration) return
            appendAndMaybeDrainAudio(webSocket, bytes.toByteArray())?.let { (current, chunk) ->
                logSink.d(
                    TAG,
                    "TTS_DIAG qwen emit generation=${current.generation} bytes=${chunk.size} " +
                        "receivedBytes=${current.receivedBytes} emittedBytes=${current.emittedBytes}"
                )
                current.onAudioChunk(chunk)
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (generation != socketGeneration) return
            synchronized(lock) {
                socketReady = false
                socketConnecting = false
                activeSocket.compareAndSet(webSocket, null)
            }
            failPending(null, IllegalStateException("语音播报通道已关闭：$code"))
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (generation != socketGeneration) return
            synchronized(lock) {
                socketReady = false
                socketConnecting = false
                activeSocket.compareAndSet(webSocket, null)
            }
            failPending(null, t)
        }
    }

    private companion object {
        private const val TAG = "QwenTaskTtsApiClient"
        private const val QWEN_TTS_PREBUFFER_BYTES = 24_000
        private const val QWEN_TTS_STREAM_CHUNK_BYTES = 5_760
        private const val IDLE_CLOSE_MS = 60_000L
        private const val FIRST_AUDIO_TIMEOUT_MS = 5_000L
        private const val MIN_SYNTHESIS_COMPLETE_TIMEOUT_MS = 15_000L
        private const val MAX_SYNTHESIS_COMPLETE_TIMEOUT_MS = 60_000L
        private const val SYNTHESIS_COMPLETE_TIMEOUT_PER_CHAR_MS = 350L
    }
}

interface QwenTaskTtsDelayScheduler {
    fun removeCallbacks(runnable: Runnable)
    fun postDelayed(runnable: Runnable, delayMillis: Long)
}

private class AndroidQwenTaskTtsDelayScheduler : QwenTaskTtsDelayScheduler {
    private val handler = Handler(Looper.getMainLooper())

    override fun removeCallbacks(runnable: Runnable) {
        handler.removeCallbacks(runnable)
    }

    override fun postDelayed(runnable: Runnable, delayMillis: Long) {
        handler.postDelayed(runnable, delayMillis)
    }
}

interface QwenTaskTtsLogSink {
    fun i(tag: String, message: String)
    fun d(tag: String, message: String)
}

private object AndroidQwenTaskTtsLogSink : QwenTaskTtsLogSink {
    override fun i(tag: String, message: String) {
        AppFileLogger.i(tag, message)
    }

    override fun d(tag: String, message: String) {
        AppFileLogger.d(tag, message)
    }
}
