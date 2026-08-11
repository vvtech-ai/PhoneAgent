package com.vvtech.aiassistant.callengine

import android.util.Log
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
internal data class AssistantTranslationIntroSpec(
    val callerLanguage: String,
    val calleeLanguage: String,
    val provider: String,
    val traceId: String
)

internal data class AssistantTranslationIntroCallbacks(
    val playLocalFrame: (ShortArray) -> Unit,
    val playRemoteFrames: (List<ShortArray>) -> Unit,
    val sendModelLocalFrame: (ShortArray) -> Unit,
    val isCallActive: () -> Boolean,
    val onFailure: (String) -> Unit
)

internal fun interface AssistantTranslationIntroTask {
    fun cancel()
}

internal class AssistantTranslationIntroCoordinator(
    private val spec: AssistantTranslationIntroSpec,
    private val callbacks: AssistantTranslationIntroCallbacks,
    private val gate: AssistantTranslationIntroGate,
    private val loadFrames: (String) -> List<ShortArray>,
    private val loadTriggerFrames: () -> List<ShortArray>,
    private val expectTriggerResponseBoundary: Boolean = false,
    private val triggerResponseTimeoutMs: Long = 5_000L,
    private val sleeper: (Long) -> Unit = Thread::sleep,
    private val launcher: (() -> Unit) -> AssistantTranslationIntroTask = ::launchIntroTask,
    private val logger: (String) -> Unit = {
        Log.i(Tag, it)
        AppFileLogger.i(Tag, it)
    }
) : AutoCloseable {
    private val started = AtomicBoolean(false)
    private val closed = AtomicBoolean(false)
    private val modelReady = AtomicBoolean(false)
    private val triggerInjected = AtomicBoolean(false)
    private val triggerResponseCompleted = AtomicBoolean(false)
    private val triggerResponseDone = CountDownLatch(1)
    private val terminalLogged = AtomicBoolean(false)
    private var task: AssistantTranslationIntroTask? = null

    fun start(): Boolean {
        if (closed.get() || !started.compareAndSet(false, true)) return false
        task = launcher(::runIntro)
        return true
    }

    fun markModelReady() {
        modelReady.set(true)
    }

    fun markModelTriggerResponseDone() {
        if (!expectTriggerResponseBoundary || !triggerInjected.get()) return
        if (!triggerResponseCompleted.compareAndSet(false, true)) return
        gate.completeTriggerResponse()
        triggerResponseDone.countDown()
        log(
            event = "model_trigger_response_completed",
            stateBefore = "discarding_trigger_response",
            stateAfter = "trigger_response_discarded"
        )
    }

    private fun runIntro() {
        val startedAt = System.currentTimeMillis()
        if (!gate.enter(expectTriggerResponseBoundary)) return
        try {
            val callerFrames = loadFrames(spec.callerLanguage)
            val calleeFrames = loadFrames(spec.calleeLanguage)
            val triggerFrames = loadTriggerFrames()
            val remoteTailFrames = (callerFrames.size - calleeFrames.size).coerceAtLeast(0)
            val remoteFrames = calleeFrames + List(remoteTailFrames) {
                AssistantTranslationIntroAudio.silenceFrame()
            }
            log(
                event = "started",
                stateBefore = "ready",
                stateAfter = "playing",
                callerFrames = callerFrames.size,
                calleeFrames = calleeFrames.size,
                triggerFrames = triggerFrames.size,
                remoteTailFrames = remoteTailFrames,
                elapsedMs = 0
            )
            val localDone = CountDownLatch(1)
            val remoteDone = CountDownLatch(1)
            launcher { playFrames("caller", callerFrames, callbacks.playLocalFrame, localDone) }
            launcher { playRemoteFrames(remoteFrames, remoteDone) }
            awaitModelReady(startedAt)
            injectModelTrigger(triggerFrames)
            localDone.await()
            remoteDone.await()
            gate.finishIntroPlayback()
            if (expectTriggerResponseBoundary && !triggerResponseCompleted.get()) {
                log(
                    event = "input_released",
                    stateBefore = "playing",
                    stateAfter = "discarding_trigger_response"
                )
                awaitTriggerResponse()
            }
            logTerminal(
                event = "completed",
                stateBefore = "playing",
                stateAfter = "translation_active",
                callerFrames = callerFrames.size,
                calleeFrames = calleeFrames.size,
                triggerFrames = triggerFrames.size,
                remoteTailFrames = remoteTailFrames,
                startedAt = startedAt
            )
        } catch (interrupted: InterruptedException) {
            Thread.currentThread().interrupt()
            gate.cancel()
            logTerminal(
                event = "cancelled",
                stateBefore = "playing",
                stateAfter = "cancelled",
                callerFrames = 0,
                calleeFrames = 0,
                reason = "interrupted",
                startedAt = startedAt
            )
        } catch (error: Exception) {
            val reason = error.message.orEmpty().ifBlank { error::class.java.simpleName }
            if (reason == "model_trigger_response_timeout") gate.failClosed() else gate.cancel()
            logTerminal(
                event = "failed",
                stateBefore = "playing",
                stateAfter = "failed",
                callerFrames = 0,
                calleeFrames = 0,
                reason = reason,
                startedAt = startedAt
            )
            if (!closed.get()) callbacks.onFailure("实时翻译开场白播放失败：$reason")
        }
    }

    private fun playRemoteFrames(frames: List<ShortArray>, done: CountDownLatch) {
        try {
            ensureActive()
            callbacks.playRemoteFrames(frames)
            log("side_completed", "playing", "playing", side = "callee", frameCount = frames.size)
        } catch (interrupted: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (error: Exception) {
            if (!closed.get()) callbacks.onFailure(error.message ?: "实时翻译开场白播放失败")
        } finally {
            done.countDown()
        }
    }

    private fun playFrames(
        side: String,
        frames: List<ShortArray>,
        output: (ShortArray) -> Unit,
        done: CountDownLatch
    ) {
        try {
            frames.forEach { frame ->
                ensureActive()
                output(frame)
                sleeper(FrameMillis)
            }
            log("side_completed", "playing", "playing", side = side, frameCount = frames.size)
        } catch (interrupted: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (error: Exception) {
            if (!closed.get()) callbacks.onFailure(error.message ?: "实时翻译开场白播放失败")
        } finally {
            done.countDown()
        }
    }

    private fun injectModelTrigger(triggerFrames: List<ShortArray>) {
        val frames = triggerFrames + List(
            AssistantTranslationIntroAudio.TailSilenceFrames
        ) { AssistantTranslationIntroAudio.silenceFrame() }
        triggerInjected.set(true)
        frames.forEach { frame ->
            ensureActive()
            callbacks.sendModelLocalFrame(frame)
            sleeper(FrameMillis)
        }
        log("model_trigger_completed", "playing", "playing", frameCount = frames.size)
    }

    private fun awaitTriggerResponse() {
        if (!triggerResponseDone.await(triggerResponseTimeoutMs, TimeUnit.MILLISECONDS)) {
            error("model_trigger_response_timeout")
        }
    }

    private fun awaitModelReady(startedAt: Long) {
        while (!modelReady.get()) {
            ensureActive()
            if (elapsed(startedAt) > ModelReadyTimeoutMs) error("model_ready_timeout")
            sleeper(FrameMillis)
        }
    }

    private fun ensureActive() {
        if (closed.get() || !callbacks.isCallActive()) error("call_inactive")
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        task?.cancel()
        task = null
        if (started.get()) {
            gate.cancel()
            logTerminal(
                event = "cancelled",
                stateBefore = "playing",
                stateAfter = "cancelled",
                callerFrames = 0,
                calleeFrames = 0,
                reason = "media_closed"
            )
        }
    }

    private fun logTerminal(
        event: String,
        stateBefore: String,
        stateAfter: String,
        callerFrames: Int,
        calleeFrames: Int,
        triggerFrames: Int = 0,
        remoteTailFrames: Int = 0,
        reason: String = "",
        startedAt: Long = System.currentTimeMillis()
    ) {
        if (!terminalLogged.compareAndSet(false, true)) return
        log(
            event,
            stateBefore,
            stateAfter,
            callerFrames,
            calleeFrames,
            triggerFrames,
            remoteTailFrames,
            reason,
            elapsed(startedAt)
        )
    }

    private fun log(
        event: String,
        stateBefore: String,
        stateAfter: String,
        callerFrames: Int = 0,
        calleeFrames: Int = 0,
        triggerFrames: Int = 0,
        remoteTailFrames: Int = 0,
        reason: String = "",
        elapsedMs: Long = 0,
        side: String = "both",
        frameCount: Int = 0
    ) {
        logger(
            "TRANSLATION_INTRO_TRACE traceId=${spec.traceId} provider=${spec.provider} " +
                "callerLanguage=${spec.callerLanguage} calleeLanguage=${spec.calleeLanguage} " +
                "event=$event stateBefore=$stateBefore stateAfter=$stateAfter side=$side " +
                "callerFrames=$callerFrames calleeFrames=$calleeFrames " +
                "triggerFrames=$triggerFrames remoteTailFrames=$remoteTailFrames " +
                "frameCount=$frameCount " +
                "elapsedMs=$elapsedMs reason=${reason.ifBlank { "none" }}"
        )
    }

    private fun elapsed(startedAt: Long): Long =
        (System.currentTimeMillis() - startedAt).coerceAtLeast(0)

    private companion object {
        private const val Tag = "AssistantSipCall"
        private const val FrameMillis = 20L
        private const val ModelReadyTimeoutMs = 12_000L
    }
}

private fun launchIntroTask(block: () -> Unit): AssistantTranslationIntroTask {
    val worker = thread(
        name = "assistant-translation-intro",
        isDaemon = true,
        block = block
    )
    return AssistantTranslationIntroTask { worker.interrupt() }
}
