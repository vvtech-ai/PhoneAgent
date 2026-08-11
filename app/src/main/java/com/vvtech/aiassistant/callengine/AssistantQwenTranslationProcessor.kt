package com.vvtech.aiassistant.callengine

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

internal class AssistantQwenTranslationProcessor(
    config: AssistantRealtimeModelConfig,
    myLanguage: String,
    peerLanguage: String,
    callbacks: AssistantTranslationProcessorCallbacks
) : AssistantRealtimeTranslationProcessor {
    private val readyDirections = AtomicInteger()
    private val local = AssistantQwenDirection(
        config = config,
        speaker = "local",
        sourceLanguage = myLanguage,
        targetLanguage = peerLanguage,
        onTranscript = callbacks.onTranscript,
        onAudio = callbacks.onTranslatedAudioToSip,
        onResponseDone = callbacks.onTranslatedAudioToSipCompleted,
        onError = callbacks.onError,
        onReady = { directionReady(callbacks.onReady) }
    )
    private val remote = AssistantQwenDirection(
        config = config,
        speaker = "remote",
        sourceLanguage = peerLanguage,
        targetLanguage = myLanguage,
        onTranscript = callbacks.onTranscript,
        onAudio = callbacks.onTranslatedAudioToLocal,
        onResponseDone = callbacks.onTranslatedAudioToLocalCompleted,
        onError = callbacks.onError,
        onReady = { directionReady(callbacks.onReady) }
    )
    override val translatedAudioCompletionSupported: Boolean = true

    override fun start() {
        local.start()
        remote.start()
    }

    override fun onLocalPcm16k(pcm16k: ShortArray) = local.send(pcm16k)
    override fun onRemotePcm16k(pcm16k: ShortArray) = remote.send(pcm16k)
    override fun setIntroTriggerResponseListener(listener: () -> Unit): Boolean =
        local.setIntroTriggerResponseListener(listener)

    override fun close() {
        local.close()
        remote.close()
    }

    private fun directionReady(onReady: () -> Unit) {
        if (readyDirections.incrementAndGet() == RequiredReadyDirections) onReady()
    }

    private companion object {
        const val RequiredReadyDirections = 2
    }
}

private class AssistantQwenDirection(
    private val config: AssistantRealtimeModelConfig,
    private val speaker: String,
    sourceLanguage: String,
    private val targetLanguage: String,
    private val onTranscript: (AssistantTranslationTranscript) -> Unit,
    private val onAudio: (ShortArray) -> Unit,
    private val onResponseDone: () -> Unit,
    private val onError: (String) -> Unit,
    private val onReady: () -> Unit
) : WebSocketListener(), AutoCloseable {
    private val client = OkHttpClient()
    private val ready = AtomicBoolean(false)
    private val closed = AtomicBoolean(false)
    private val pending = ArrayDeque<ShortArray>()
    private val lock = Any()
    private val parser = AssistantQwenEventParser(
        speaker = speaker,
        sourceLanguage = sourceLanguage,
        targetLanguage = targetLanguage,
        outputSampleRate = config.outputSampleRate
    )
    private val introTriggerResponseListener = AtomicReference<(() -> Unit)?>(null)
    private val sourceLanguage = sourceLanguage
    private var socket: WebSocket? = null

    fun start() {
        if (!config.configured) {
            onError("Qwen 实时翻译配置缺失")
            return
        }
        val request = Request.Builder()
            .url(AssistantQwenProtocol.modelUrl(config))
            .header("Authorization", "Bearer ${config.apiKey}")
            .build()
        socket = client.newWebSocket(request, this)
    }

    fun send(pcm16k: ShortArray) {
        if (closed.get() || pcm16k.isEmpty()) return
        if (!ready.get()) {
            synchronized(lock) {
                if (pending.size >= MaxPendingFrames) pending.removeFirst()
                pending.addLast(pcm16k.copyOf())
            }
            return
        }
        socket?.send(AssistantQwenProtocol.appendAudio(pcm16k))
    }

    fun setIntroTriggerResponseListener(listener: () -> Unit): Boolean {
        introTriggerResponseListener.set(listener)
        return true
    }

    override fun onOpen(webSocket: WebSocket, response: Response) {
        webSocket.send(
            AssistantQwenProtocol.sessionUpdate(
                config = config,
                sourceLanguage = sourceLanguage,
                targetLanguage = targetLanguage
            )
        )
        ready.set(true)
        onReady()
        val frames = synchronized(lock) {
            pending.toList().also { pending.clear() }
        }
        frames.forEach(::send)
    }

    override fun onMessage(webSocket: WebSocket, text: String) {
        when (val event = parser.parse(text)) {
            is AssistantQwenEvent.Transcript -> onTranscript(event.value)
            is AssistantQwenEvent.Audio -> onAudio(event.pcm)
            is AssistantQwenEvent.Error -> onError(event.message)
            AssistantQwenEvent.ResponseDone -> {
                introTriggerResponseListener.getAndSet(null)?.invoke()
                onResponseDone()
            }
            AssistantQwenEvent.Finished -> close()
            null -> Unit
        }
    }

    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        if (!closed.get()) onError(t.message ?: "Qwen 实时翻译连接失败")
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        if (ready.get()) runCatching { socket?.send(AssistantQwenProtocol.finish()) }
        socket?.close(1000, "done")
        socket = null
        introTriggerResponseListener.set(null)
        synchronized(lock) { pending.clear() }
        client.dispatcher.executorService.shutdown()
    }

    private companion object {
        const val MaxPendingFrames = 80
    }
}
