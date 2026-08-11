package com.vvtech.aiassistant.callengine

import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.LockSupport
import kotlin.concurrent.thread
import kotlin.math.max

internal class AssistantTranslatedUplinkPlayout(
    private val traceId: String,
    private val sendFrame: (ShortArray) -> Unit,
    private val onFailure: (String) -> Unit,
    private val logger: (String) -> Unit = { Log.i(Tag, it) }
) : AutoCloseable {
    private val running = AtomicBoolean()
    private val firstEnqueueLogged = AtomicBoolean()
    private val sentFrames = AtomicLong()
    private val fillerFrames = AtomicLong()
    private val underflows = AtomicLong()
    private val queue = AssistantTranslatedAudioFrameQueue(
        frameSamples = FrameSamples,
        maxQueuedSamples = MaxQueuedSamples
    )
    private val pacer = AssistantRtpFramePacer()
    private var workerThread: Thread? = null
    private var startedRealPlayout = false
    private var buffering = true
    private var maxPacingLagNanos = 0L

    fun start() {
        if (!running.compareAndSet(false, true)) return
        workerThread = thread(
            start = true,
            isDaemon = true,
            name = "assistant-translated-uplink"
        ) { playoutLoop() }
        log("started", "targetBufferMs=$TargetBufferMs frameMs=$FrameDurationMs")
    }

    fun enqueue(pcm16k: ShortArray): Boolean {
        if (!running.get() || pcm16k.isEmpty()) return false
        val result = queue.enqueue(pcm16k)
        if (!result.accepted) {
            log(
                "overflow",
                "samples=${pcm16k.size} queuedAudioMs=${result.queuedAudioMs}"
            )
            return false
        }
        if (firstEnqueueLogged.compareAndSet(false, true)) {
            log(
                "first_enqueued",
                "samples=${pcm16k.size} queuedAudioMs=${result.queuedAudioMs}"
            )
        }
        workerThread?.let(LockSupport::unpark)
        return true
    }

    override fun close() {
        if (!running.compareAndSet(true, false)) return
        val worker = workerThread
        workerThread = null
        worker?.interrupt()
        worker?.let(LockSupport::unpark)
        log(
            "closed",
            "sentFrames=${sentFrames.get()} fillerFrames=${fillerFrames.get()} " +
                "underflows=${underflows.get()} queuedAudioMs=${queue.queuedAudioMs()} " +
                "maxPacingLagMs=${maxPacingLagNanos / NanosPerMillisecond}"
        )
        queue.clear()
    }

    private fun playoutLoop() {
        try {
            while (running.get()) {
                if (buffering && queue.queuedSamples() < TargetBufferSamples) {
                    if (startedRealPlayout) sendPaced(SilenceFrame, filler = true)
                    else LockSupport.parkNanos(IdlePollNanos)
                    continue
                }
                if (buffering) {
                    log(
                        if (startedRealPlayout) "resume_ready" else "buffer_ready",
                        "queuedAudioMs=${queue.queuedAudioMs()}"
                    )
                    buffering = false
                }
                val frame = queue.pollFrame()
                if (frame == null) {
                    buffering = true
                    if (startedRealPlayout) {
                        underflows.incrementAndGet()
                        log("underflow", "queuedAudioMs=${queue.queuedAudioMs()}")
                    }
                    continue
                }
                sendPaced(frame, filler = false)
                startedRealPlayout = true
            }
        } catch (error: Throwable) {
            if (running.getAndSet(false)) {
                onFailure(error.message ?: "翻译音频 RTP 发送失败")
            }
        }
    }

    private fun sendPaced(frame: ShortArray, filler: Boolean) {
        val lag = pacer.paceBeforeSend()
        maxPacingLagNanos = max(maxPacingLagNanos, lag)
        if (!running.get()) return
        sendFrame(frame)
        if (filler) fillerFrames.incrementAndGet() else sentFrames.incrementAndGet()
    }

    private fun log(event: String, detail: String) {
        logger("SIP_TRANSLATED_AUDIO_TRACE traceId=$traceId event=$event $detail")
    }

    private companion object {
        const val Tag = "AssistantSipCall"
        const val SampleRate = 16_000
        const val FrameDurationMs = 20
        const val TargetBufferMs = 160
        const val MaxQueuedAudioMs = 30_000
        const val NanosPerMillisecond = 1_000_000L
        const val IdlePollNanos = 5 * NanosPerMillisecond
        const val FrameSamples = SampleRate * FrameDurationMs / 1_000
        const val TargetBufferSamples = SampleRate * TargetBufferMs / 1_000
        const val MaxQueuedSamples = SampleRate * MaxQueuedAudioMs / 1_000
        val SilenceFrame = ShortArray(FrameSamples)
    }
}

internal class AssistantRtpFramePacer(
    private val frameIntervalNanos: Long = 20_000_000L,
    private val nanoTime: () -> Long = System::nanoTime,
    private val parkNanos: (Long) -> Unit = LockSupport::parkNanos
) {
    private var nextSendAtNanos = Long.MIN_VALUE

    fun paceBeforeSend(): Long {
        val now = nanoTime()
        if (nextSendAtNanos == Long.MIN_VALUE) nextSendAtNanos = now
        val scheduledAt = nextSendAtNanos
        val delay = scheduledAt - now
        if (delay > 0L) parkNanos(delay)
        val afterPace = nanoTime()
        val lag = max(0L, afterPace - scheduledAt)
        nextSendAtNanos = if (lag > frameIntervalNanos) {
            afterPace + frameIntervalNanos
        } else {
            scheduledAt + frameIntervalNanos
        }
        return lag
    }
}

internal class AssistantTranslatedAudioFrameQueue(
    private val frameSamples: Int,
    private val maxQueuedSamples: Int
) {
    private data class Chunk(val pcm: ShortArray, var offset: Int = 0)

    private val chunks = ArrayDeque<Chunk>()
    private var queuedSamples = 0

    @Synchronized
    fun enqueue(pcm: ShortArray): AssistantTranslatedAudioEnqueueResult {
        if (pcm.isEmpty() || queuedSamples + pcm.size > maxQueuedSamples) {
            return AssistantTranslatedAudioEnqueueResult(false, queuedAudioMs())
        }
        chunks.addLast(Chunk(pcm.copyOf()))
        queuedSamples += pcm.size
        return AssistantTranslatedAudioEnqueueResult(true, queuedAudioMs())
    }

    @Synchronized
    fun pollFrame(): ShortArray? {
        if (queuedSamples < frameSamples) return null
        val frame = ShortArray(frameSamples)
        var targetOffset = 0
        while (targetOffset < frameSamples) {
            val chunk = chunks.first()
            val count = minOf(frameSamples - targetOffset, chunk.pcm.size - chunk.offset)
            System.arraycopy(chunk.pcm, chunk.offset, frame, targetOffset, count)
            chunk.offset += count
            targetOffset += count
            queuedSamples -= count
            if (chunk.offset == chunk.pcm.size) chunks.removeFirst()
        }
        return frame
    }

    @Synchronized
    fun queuedSamples(): Int = queuedSamples

    @Synchronized
    fun hasPlayableFrame(): Boolean = queuedSamples >= frameSamples

    @Synchronized
    fun queuedAudioMs(): Int = queuedSamples * 1_000 / 16_000

    @Synchronized
    fun clear() {
        chunks.clear()
        queuedSamples = 0
    }
}

internal data class AssistantTranslatedAudioEnqueueResult(
    val accepted: Boolean,
    val queuedAudioMs: Int
)
