package com.vvtech.aiassistant.callengine

import android.util.Log
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.LockSupport
import kotlin.concurrent.thread
import kotlin.math.roundToInt

internal class AssistantOriginalAudioMixPlayout(
    private val traceId: String,
    private val direction: String,
    targetOriginalRatio: Float,
    pureOriginalGain: Float,
    maxOriginalGain: Float? = null,
    responseBoundarySupported: Boolean = false,
    private val outputFrame: (ShortArray) -> Unit,
    private val onFailure: (String) -> Unit,
    private val logger: (String) -> Unit = {
        Log.i(Tag, it)
        AppFileLogger.i(Tag, it)
    }
) : AutoCloseable {
    private val targetOriginalRatio = targetOriginalRatio.coerceIn(0f, 1f)
    private val pureOriginalGain = pureOriginalGain.coerceIn(0f, 1f)
    private val levelController =
        AssistantOriginalAudioLevelController(
            targetOriginalRatio = this.targetOriginalRatio,
            pureOriginalGain = this.pureOriginalGain,
            maxOriginalGain = maxOriginalGain ?: DefaultDynamicOriginalGainLimit
        )
    private val running = AtomicBoolean()
    private val originalQueue = AssistantTranslatedAudioFrameQueue(
        FrameSamples,
        MaxOriginalQueuedSamples
    )
    private val translatedQueue = AssistantTranslatedAudioFrameQueue(
        FrameSamples,
        MaxTranslatedQueuedSamples
    )
    private val pacer = AssistantRtpFramePacer()
    private val duckingController =
        AssistantTranslationDuckingController(responseBoundarySupported)
    private var workerThread: Thread? = null
    private var duckingState = AssistantTranslationDuckingState.ORIGINAL_ONLY
    private var lastOutputGain = this.pureOriginalGain
    private var attackStartGain = this.pureOriginalGain
    private var releaseStartGain = this.pureOriginalGain
    private val diagnostics = AssistantOriginalAudioMixDiagnostics()

    fun start() {
        if (!running.compareAndSet(false, true)) return
        workerThread = thread(
            start = true,
            isDaemon = true,
            name = "assistant-original-mix-$direction"
        ) { playoutLoop() }
        log(
            "started",
            "originalAudioEnabled=true " +
                "targetOriginalRatioPercent=${gainPercent(targetOriginalRatio)} " +
                "pureOriginalGainPercent=${gainPercent(pureOriginalGain)} " +
                timingLog()
        )
    }

    fun enqueueOriginal(pcm16k: ShortArray): Boolean = enqueue(originalQueue, pcm16k)

    fun enqueueTranslated(pcm16k: ShortArray): Boolean =
        enqueue(translatedQueue, pcm16k) {
            duckingController.onTranslatedAudio(System.nanoTime())
        }

    fun markTranslationResponseDone() {
        if (!running.get()) return
        duckingController.onResponseDone(System.nanoTime())
        workerThread?.let(LockSupport::unpark)
    }

    private fun enqueue(
        queue: AssistantTranslatedAudioFrameQueue,
        pcm16k: ShortArray,
        onAccepted: () -> Unit = {}
    ): Boolean {
        if (!running.get() || pcm16k.isEmpty()) return false
        val accepted = queue.enqueue(pcm16k).accepted
        if (accepted) onAccepted()
        workerThread?.let(LockSupport::unpark)
        return accepted
    }

    override fun close() {
        if (!running.compareAndSet(true, false)) return
        workerThread?.interrupt()
        workerThread?.let(LockSupport::unpark)
        workerThread = null
        originalQueue.clear()
        translatedQueue.clear()
        log("closed", "originalAudioEnabled=true")
    }

    private fun playoutLoop() {
        try {
            while (running.get()) {
                val translated = translatedQueue.pollFrame()
                val original = originalQueue.pollFrame()
                val nowNanos = System.nanoTime()
                if (translated != null) duckingController.ensureTranslatedAudioActive(nowNanos)
                val ducking = duckingController.next(
                    nowNanos = nowNanos,
                    translatedAudioQueued =
                        translated != null || translatedQueue.hasPlayableFrame()
                )
                if (translated == null && original == null) {
                    val level = resolveLevel(null, null, ducking)
                    updateDuckingState(ducking, level)
                    LockSupport.parkNanos(IdlePollNanos)
                    continue
                }
                val level = resolveLevel(original, translated, ducking)
                updateDuckingState(ducking, level)
                pacer.paceBeforeSend()
                if (!running.get()) return
                val mixed = mix(
                    original,
                    translated,
                    level.appliedGain,
                    ducking.usesResolvedGain,
                    pureOriginalGain
                )
                diagnostics.record(
                    original = original,
                    translated = translated,
                    output = mixed,
                    level = level,
                    targetOriginalRatio = targetOriginalRatio
                )?.let {
                    log("levels", it)
                }
                outputFrame(mixed)
            }
        } catch (error: Throwable) {
            if (running.getAndSet(false)) {
                onFailure(error.message ?: "原声混播失败")
            }
        }
    }

    private fun resolveLevel(
        original: ShortArray?,
        translated: ShortArray?,
        ducking: AssistantTranslationDuckingDecision
    ): AssistantOriginalAudioLevelDecision {
        val level = when (ducking.state) {
            AssistantTranslationDuckingState.ORIGINAL_ONLY -> {
                levelController.nextGain(original, translated, translationWindowActive = false)
                AssistantOriginalAudioLevelDecision(
                    appliedGain = pureOriginalGain,
                    targetGain = pureOriginalGain,
                    balanced = false,
                    gainLimited = false
                )
            }
            AssistantTranslationDuckingState.ATTACK -> {
                if (duckingState != AssistantTranslationDuckingState.ATTACK) {
                    attackStartGain = lastOutputGain
                }
                val mixed = levelController.nextGain(
                    original,
                    translated,
                    translationWindowActive = true
                )
                mixed.copy(
                    appliedGain = interpolate(
                        attackStartGain,
                        mixed.appliedGain,
                        ducking.attackProgress
                    )
                )
            }
            AssistantTranslationDuckingState.TRANSLATION_ACTIVE,
            AssistantTranslationDuckingState.GAP_HOLD ->
                levelController.nextGain(original, translated, translationWindowActive = true)
            AssistantTranslationDuckingState.RELEASE -> {
                if (duckingState != AssistantTranslationDuckingState.RELEASE) {
                    releaseStartGain = lastOutputGain
                }
                AssistantOriginalAudioLevelDecision(
                    appliedGain = interpolate(
                        releaseStartGain,
                        pureOriginalGain,
                        ducking.releaseProgress
                    ),
                    targetGain = pureOriginalGain,
                    balanced = false,
                    gainLimited = false
                )
            }
        }
        lastOutputGain = level.appliedGain
        return level
    }

    private fun updateDuckingState(
        decision: AssistantTranslationDuckingDecision,
        level: AssistantOriginalAudioLevelDecision
    ) {
        if (duckingState == decision.state) return
        val previous = duckingState
        duckingState = decision.state
        log(
            "ducking_state_changed",
            "stateBefore=$previous stateAfter=${decision.state} " +
                "reason=${decision.reason} " +
                "targetOriginalRatioPercent=${gainPercent(targetOriginalRatio)} " +
                "appliedOriginalGain=${formatGain(level.appliedGain)} " +
                "appliedOriginalGainPercent=${gainPercent(level.appliedGain)} " +
                timingLog()
        )
    }

    private fun timingLog(): String {
        val timings = duckingController.timings
        return "attackMs=${timings.attackNanos / 1_000_000L} " +
            "holdMs=${timings.fallbackHoldNanos / 1_000_000L} " +
            "completionTailMs=${timings.completionTailNanos / 1_000_000L} " +
            "releaseMs=${timings.releaseNanos / 1_000_000L} " +
            "watchdogMs=${timings.responseWatchdogNanos / 1_000_000L}"
    }

    private fun log(event: String, detail: String) {
        logger(
            "SIP_ORIGINAL_AUDIO_MIX traceId=$traceId direction=$direction " +
                "event=$event $detail"
        )
    }

    companion object {
        fun mix(
            original: ShortArray?,
            translated: ShortArray?,
            resolvedOriginalGain: Float,
            translatedActive: Boolean = translated != null,
            pureOriginalGain: Float = 1f
        ): ShortArray {
            val size = maxOf(original?.size ?: 0, translated?.size ?: 0)
            if (size == 0) return ShortArray(0)
            val originalGain = if (translatedActive) {
                resolvedOriginalGain.coerceAtLeast(0f)
            } else {
                pureOriginalGain.coerceIn(0f, 1f)
            }
            return ShortArray(size) { index ->
                val originalSample = original?.getOrNull(index)?.times(originalGain) ?: 0f
                val translatedSample = translated?.getOrNull(index)?.toFloat() ?: 0f
                (originalSample + translatedSample)
                    .roundToInt()
                    .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                    .toShort()
            }
        }

        fun rmsDbfs(pcm: ShortArray?): Double {
            val samples = pcm?.takeIf { it.isNotEmpty() }
                ?: return Double.NEGATIVE_INFINITY
            val meanSquare = samples.sumOf { sample ->
                val normalized = sample.toDouble() / Short.MAX_VALUE
                normalized * normalized
            } / samples.size
            return if (meanSquare <= 0.0) {
                Double.NEGATIVE_INFINITY
            } else {
                20.0 * kotlin.math.log10(kotlin.math.sqrt(meanSquare))
            }
        }

        private fun gainPercent(gain: Float): Int = (gain * 100f).roundToInt()
        private fun formatGain(gain: Float): String =
            "%.3f".format(java.util.Locale.ROOT, gain)
        private fun interpolate(start: Float, end: Float, progress: Float): Float =
            start + (end - start) * progress.coerceIn(0f, 1f)

        private const val Tag = "AssistantSipCall"
        private const val SampleRate = 16_000
        private const val FrameDurationMs = 20
        private const val FrameSamples = SampleRate * FrameDurationMs / 1_000
        private const val MaxOriginalQueuedSamples = SampleRate * 2
        private const val MaxTranslatedQueuedSamples = SampleRate * 30
        private const val IdlePollNanos = 5_000_000L
        private const val DefaultDynamicOriginalGainLimit = 8f
    }
}
