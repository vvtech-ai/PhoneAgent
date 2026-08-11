package com.vvtech.aiassistant.callengine

import android.util.Log
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.LockSupport
import kotlin.concurrent.thread

internal class AssistantTranslationIntroRemotePlayback(
    private val traceId: String,
    private val outputFrame: (ShortArray) -> Unit,
    private val onFailure: (String) -> Unit,
    private val isCallActive: () -> Boolean
) : AutoCloseable {
    @Volatile
    private var activePlayout: AssistantTranslationIntroRemotePlayout? = null

    fun play(frames: List<ShortArray>) {
        val playout = AssistantTranslationIntroRemotePlayout(
            traceId = traceId,
            outputFrame = outputFrame,
            onFailure = onFailure
        )
        activePlayout = playout
        playout.start()
        try {
            frames.forEach { frame ->
                if (!isCallActive()) return
                playout.enqueue(frame)
            }
            playout.finishAndAwait()
        } finally {
            playout.close()
            if (activePlayout === playout) activePlayout = null
        }
    }

    override fun close() {
        activePlayout?.close()
        activePlayout = null
    }
}

internal class AssistantTranslationIntroRemotePlayout(
    private val traceId: String,
    private val outputFrame: (ShortArray) -> Unit,
    private val onFailure: (String) -> Unit,
    private val logger: (String) -> Unit = {
        Log.i(Tag, it)
        AppFileLogger.i(Tag, it)
    }
) : AutoCloseable {
    private val active = AtomicBoolean()
    private val inputClosed = AtomicBoolean()
    private val finished = CountDownLatch(1)
    private val queue = AssistantTranslatedAudioFrameQueue(FrameSamples, MaxQueuedSamples)
    private val pacer = AssistantRtpFramePacer()
    private val sentFrames = AtomicLong()
    private var workerThread: Thread? = null

    fun start() {
        if (!active.compareAndSet(false, true)) return
        workerThread = thread(
            start = true,
            isDaemon = true,
            name = "assistant-translation-intro-remote"
        ) { playoutLoop() }
        log("started", "preSilenceMs=$PreSilenceMs targetBufferMs=$TargetBufferMs")
    }

    fun enqueue(pcm16k: ShortArray): Boolean {
        if (!active.get() || inputClosed.get() || pcm16k.isEmpty()) return false
        val result = queue.enqueue(pcm16k)
        if (!result.accepted) {
            log("overflow", "samples=${pcm16k.size} queuedAudioMs=${result.queuedAudioMs}")
            return false
        }
        workerThread?.let(LockSupport::unpark)
        return true
    }

    fun finishAndAwait() {
        closeInput()
        finished.await()
    }

    override fun close() {
        closeInput()
        workerThread?.interrupt()
        workerThread?.let(LockSupport::unpark)
    }

    private fun closeInput() {
        inputClosed.set(true)
        workerThread?.let(LockSupport::unpark)
    }

    private fun playoutLoop() {
        try {
            awaitInitialBuffer()
            sendPreSilence()
            while (active.get() && (!inputClosed.get() || queue.queuedSamples() >= FrameSamples)) {
                val frame = queue.pollFrame()
                if (frame == null) {
                    LockSupport.parkNanos(IdlePollNanos)
                    continue
                }
                sendPaced(frame)
            }
            log("completed", "sentFrames=${sentFrames.get()}")
        } catch (interrupted: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (error: Throwable) {
            if (active.getAndSet(false)) {
                onFailure(error.message ?: "实时翻译开场白远端播放失败")
            }
        } finally {
            active.set(false)
            queue.clear()
            workerThread = null
            finished.countDown()
        }
    }

    private fun awaitInitialBuffer() {
        while (
            active.get() &&
            !inputClosed.get() &&
            queue.queuedSamples() < TargetBufferSamples
        ) {
            LockSupport.parkNanos(IdlePollNanos)
        }
    }

    private fun sendPreSilence() {
        repeat(PreSilenceFrames) {
            if (!active.get()) return
            sendPaced(SilenceFrame)
        }
    }

    private fun sendPaced(frame: ShortArray) {
        val lag = pacer.paceBeforeSend()
        if (!active.get()) return
        outputFrame(frame)
        sentFrames.incrementAndGet()
        if (lag > ReportLagThresholdNanos) {
            log("pacing_lag", "lagMs=${lag / NanosPerMillisecond}")
        }
    }

    private fun log(event: String, detail: String) {
        logger("TRANSLATION_INTRO_REMOTE_PLAYOUT traceId=$traceId event=$event $detail")
    }

    private companion object {
        const val Tag = "AssistantSipCall"
        const val SampleRate = 16_000
        const val FrameDurationMs = 20
        const val FrameSamples = SampleRate * FrameDurationMs / 1_000
        const val PreSilenceMs = 200
        const val TargetBufferMs = 160
        const val MaxQueuedAudioMs = 15_000
        const val NanosPerMillisecond = 1_000_000L
        const val ReportLagThresholdNanos = 40 * NanosPerMillisecond
        const val IdlePollNanos = 5 * NanosPerMillisecond
        const val PreSilenceFrames = PreSilenceMs / FrameDurationMs
        const val TargetBufferSamples = SampleRate * TargetBufferMs / 1_000
        const val MaxQueuedSamples = SampleRate * MaxQueuedAudioMs / 1_000
        val SilenceFrame = ShortArray(FrameSamples)
    }
}
