package com.vvtech.aiassistant.callengine

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

internal class AssistantDoubaoTranslationProcessor(
    config: AssistantRealtimeModelConfig,
    myLanguage: String,
    peerLanguage: String,
    callbacks: AssistantTranslationProcessorCallbacks
) : AssistantRealtimeTranslationProcessor {
    private val readyDirections = AtomicInteger()
    override val originalAudioDynamicBoostEnabled: Boolean = false
    private val local = AssistantDoubaoDirection(
        config,
        "local",
        myLanguage,
        peerLanguage,
        callbacks.onTranscript,
        callbacks.onTranslatedAudioToSip,
        callbacks.onTranslatedAudioToSipCompleted,
        callbacks.onError,
        onReady = { directionReady(callbacks.onReady) }
    )
    private val remote = AssistantDoubaoDirection(
        config,
        "remote",
        peerLanguage,
        myLanguage,
        callbacks.onTranscript,
        callbacks.onTranslatedAudioToLocal,
        callbacks.onTranslatedAudioToLocalCompleted,
        callbacks.onError,
        onReady = { directionReady(callbacks.onReady) }
    )

    override fun start() {
        local.start()
        remote.start()
    }

    override fun onLocalPcm16k(pcm16k: ShortArray) = local.send(pcm16k)
    override fun onRemotePcm16k(pcm16k: ShortArray) = remote.send(pcm16k)

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

private class AssistantDoubaoDirection(
    private val config: AssistantRealtimeModelConfig,
    private val speaker: String,
    private val sourceLanguage: String,
    private val targetLanguage: String,
    private val onTranscript: (AssistantTranslationTranscript) -> Unit,
    private val onAudio: (ShortArray) -> Unit,
    private val onAudioCompleted: () -> Unit,
    private val onError: (String) -> Unit,
    private val onReady: () -> Unit,
    private val transport: AssistantDoubaoTransport = OkHttpAssistantDoubaoTransport()
) : AssistantDoubaoTransportListener, AutoCloseable {
    private val closed = AtomicBoolean(false)
    private val ready = AtomicBoolean(false)
    private val sequence = AtomicInteger(0)
    private val lastSentAtNanos = AtomicLong(0)
    private val connectionId = UUID.randomUUID().toString()
    private val sessionId = UUID.randomUUID().toString()
    private val transcriptAccumulator = AssistantDoubaoTranscriptAccumulator(
        speaker = speaker,
        sourceLanguage = sourceLanguage,
        targetLanguage = targetLanguage
    )
    private val audioCompletionGate = AssistantDoubaoTranslationAudioCompletionGate(
        speaker = speaker,
        onCompleted = onAudioCompleted
    )
    private var keepAliveThread: Thread? = null

    fun start() {
        if (!config.configured) {
            onError(currentAppText(
                "Doubao AST 实时翻译配置缺失",
                "Doubao AST realtime translation configuration is missing"
            ))
            return
        }
        transport.connect(
            url = config.websocketUrl,
            headers = AssistantDoubaoProtocol.headers(config),
            listener = this
        )
    }

    fun send(pcm16k: ShortArray) {
        if (!closed.get() && ready.get() && pcm16k.isNotEmpty()) sendAudio(pcm16k)
    }

    override fun onOpen() {
        transport.send(
            AssistantDoubaoProtocol.start(
                config = config,
                sourceLanguage = sourceLanguage,
                targetLanguage = targetLanguage,
                connectionId = connectionId,
                sessionId = sessionId,
                sequence = sequence.getAndIncrement()
            )
        )
    }

    override fun onBinary(payload: ByteArray) {
        val response = runCatching { AssistantDoubaoProto.decode(payload) }
            .getOrElse {
                onError(it.message ?: "Doubao AST 响应解析失败")
                return
            }
        if (response.statusCode != 0 && response.statusCode != AssistantDoubaoProto.StatusSuccess) {
            onError(response.message.ifBlank { "Doubao AST 服务异常 ${response.statusCode}" })
            return
        }
        when (response.event) {
            AssistantDoubaoProto.SessionStarted -> {
                ready.set(true)
                onReady()
                lastSentAtNanos.set(System.nanoTime())
                startKeepAlive()
            }
            AssistantDoubaoProto.SourceStart,
            AssistantDoubaoProto.SourceResponse,
            AssistantDoubaoProto.SourceEnd ->
                transcriptAccumulator.applySource(response.text, response.event)
                    ?.let(onTranscript)
            AssistantDoubaoProto.TranslationStart -> {
                audioCompletionGate.onTranslationStart()
                transcriptAccumulator.applyTranslation(response.text, response.event)
                    ?.let(onTranscript)
            }
            AssistantDoubaoProto.TranslationResponse ->
                transcriptAccumulator.applyTranslation(response.text, response.event)
                    ?.let(onTranscript)
            AssistantDoubaoProto.TranslationEnd -> {
                transcriptAccumulator.applyTranslation(response.text, response.event)
                    ?.let(onTranscript)
                audioCompletionGate.onTranslationEnd()
            }
            AssistantDoubaoProto.TtsResponse ->
                if (response.data.isNotEmpty()) {
                    audioCompletionGate.onAudioChunk()
                    onAudio(AssistantPcmResampler.fromLittleEndian(response.data))
                }
            AssistantDoubaoProto.SessionFailed ->
                onError(response.text.ifBlank { "Doubao AST 会话失败" })
        }
    }

    override fun onFailure(message: String) {
        if (!closed.get()) onError(message)
    }

    override fun onClosed() {
        ready.set(false)
    }

    private fun startKeepAlive() {
        if (keepAliveThread != null) return
        keepAliveThread = thread(name = "doubao-keepalive-$speaker", isDaemon = true) {
            while (!closed.get()) {
                if (ready.get() && shouldSendKeepAlive()) {
                    sendAudio(AssistantDoubaoProtocol.silenceFrame())
                }
                try {
                    Thread.sleep(KeepAlivePollMillis)
                } catch (_: InterruptedException) {
                    return@thread
                }
            }
        }
    }

    private fun shouldSendKeepAlive(): Boolean =
        System.nanoTime() - lastSentAtNanos.get() >= KeepAliveFrameMillis * 1_000_000L

    private fun sendAudio(pcm16k: ShortArray) {
        transport.send(
            AssistantDoubaoProtocol.audio(
                connectionId,
                sessionId,
                sequence.getAndIncrement(),
                pcm16k
            )
        )
        lastSentAtNanos.set(System.nanoTime())
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        audioCompletionGate.close()
        keepAliveThread?.interrupt()
        if (ready.get()) {
            transport.send(
                AssistantDoubaoProtocol.finish(
                    connectionId,
                    sessionId,
                    sequence.getAndIncrement()
                )
            )
        }
        transport.close()
    }

    private companion object {
        const val KeepAliveFrameMillis = 20L
        const val KeepAlivePollMillis = 5L
    }
}

internal class AssistantDoubaoTranslationAudioCompletionGate(
    private val speaker: String,
    private val completionDelayMs: Long = CompletionDelayMs,
    private val onCompleted: () -> Unit
) : AutoCloseable {
    private val closed = AtomicBoolean(false)
    private val lock = Any()
    private var completionToken = 0
    private var translationEndPending = false
    private var completionThread: Thread? = null

    fun onTranslationStart() {
        cancelPending()
    }

    fun onTranslationEnd() {
        synchronized(lock) {
            if (closed.get()) return
            translationEndPending = true
        }
        scheduleCompletion()
    }

    fun onAudioChunk() {
        val shouldDelayCompletion = synchronized(lock) {
            !closed.get() && translationEndPending
        }
        if (shouldDelayCompletion) scheduleCompletion()
    }

    private fun scheduleCompletion() {
        synchronized(lock) {
            if (closed.get() || !translationEndPending) return
            completionToken += 1
            val token = completionToken
            completionThread?.interrupt()
            completionThread = thread(
                name = "doubao-translation-audio-done-$speaker",
                isDaemon = true
            ) {
                try {
                    Thread.sleep(completionDelayMs)
                } catch (_: InterruptedException) {
                    return@thread
                }
                val shouldComplete = synchronized(lock) {
                    if (closed.get() || !translationEndPending || completionToken != token) {
                        false
                    } else {
                        translationEndPending = false
                        completionToken += 1
                        completionThread = null
                        true
                    }
                }
                if (shouldComplete) onCompleted()
            }
        }
    }

    private fun cancelPending() {
        synchronized(lock) {
            translationEndPending = false
            completionToken += 1
            completionThread?.interrupt()
            completionThread = null
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        cancelPending()
    }

    private companion object {
        const val CompletionDelayMs = 220L
    }
}
