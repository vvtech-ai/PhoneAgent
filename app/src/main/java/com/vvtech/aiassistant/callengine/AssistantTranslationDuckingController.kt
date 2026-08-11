package com.vvtech.aiassistant.callengine

internal enum class AssistantTranslationDuckingState {
    ORIGINAL_ONLY,
    ATTACK,
    TRANSLATION_ACTIVE,
    GAP_HOLD,
    RELEASE
}

internal data class AssistantTranslationDuckingDecision(
    val state: AssistantTranslationDuckingState,
    val reason: String,
    val attackProgress: Float = 1f,
    val releaseProgress: Float = 0f
) {
    val keepsMixedGain: Boolean
        get() = state == AssistantTranslationDuckingState.ATTACK ||
            state == AssistantTranslationDuckingState.TRANSLATION_ACTIVE ||
            state == AssistantTranslationDuckingState.GAP_HOLD

    val usesResolvedGain: Boolean
        get() = state != AssistantTranslationDuckingState.ORIGINAL_ONLY
}

internal data class AssistantTranslationDuckingTimings(
    val attackNanos: Long = milliseconds(AttackMs),
    val fallbackHoldNanos: Long = milliseconds(FallbackHoldMs),
    val completionTailNanos: Long = milliseconds(CompletionTailMs),
    val releaseNanos: Long = milliseconds(ReleaseMs),
    val responseWatchdogNanos: Long = milliseconds(ResponseWatchdogMs)
) {
    companion object {
        const val AttackMs = 40L
        const val FallbackHoldMs = 700L
        const val CompletionTailMs = 200L
        const val ReleaseMs = 350L
        const val ResponseWatchdogMs = 1_500L

        private fun milliseconds(value: Long): Long = value * 1_000_000L
    }
}

internal class AssistantTranslationDuckingController(
    private val responseBoundarySupported: Boolean,
    val timings: AssistantTranslationDuckingTimings = AssistantTranslationDuckingTimings()
) {
    private var state = AssistantTranslationDuckingState.ORIGINAL_ONLY
    private var stateStartedAtNanos = 0L
    private var gapStartedAtNanos = Long.MIN_VALUE
    private var responseDoneAtNanos = Long.MIN_VALUE
    private var reason = "initialized"

    @Synchronized
    fun onTranslatedAudio(nowNanos: Long) {
        responseDoneAtNanos = Long.MIN_VALUE
        when (state) {
            AssistantTranslationDuckingState.ORIGINAL_ONLY ->
                transition(
                    AssistantTranslationDuckingState.ATTACK,
                    nowNanos,
                    "translated_audio_started"
                )
            AssistantTranslationDuckingState.RELEASE ->
                transition(
                    AssistantTranslationDuckingState.ATTACK,
                    nowNanos,
                    "translated_audio_resumed"
                )
            AssistantTranslationDuckingState.GAP_HOLD ->
                transition(
                    AssistantTranslationDuckingState.TRANSLATION_ACTIVE,
                    nowNanos,
                    "translated_audio_resumed"
                )
            AssistantTranslationDuckingState.ATTACK,
            AssistantTranslationDuckingState.TRANSLATION_ACTIVE -> Unit
        }
        gapStartedAtNanos = Long.MIN_VALUE
    }

    @Synchronized
    fun onResponseDone(nowNanos: Long) {
        if (state != AssistantTranslationDuckingState.ORIGINAL_ONLY) {
            responseDoneAtNanos = nowNanos
        }
    }

    @Synchronized
    fun ensureTranslatedAudioActive(nowNanos: Long) {
        if (state == AssistantTranslationDuckingState.ORIGINAL_ONLY ||
            state == AssistantTranslationDuckingState.RELEASE
        ) {
            onTranslatedAudio(nowNanos)
        }
    }

    @Synchronized
    fun next(
        nowNanos: Long,
        translatedAudioQueued: Boolean
    ): AssistantTranslationDuckingDecision {
        when (state) {
            AssistantTranslationDuckingState.ORIGINAL_ONLY -> Unit
            AssistantTranslationDuckingState.ATTACK -> {
                if (elapsed(nowNanos, stateStartedAtNanos) >= timings.attackNanos) {
                    transition(
                        AssistantTranslationDuckingState.TRANSLATION_ACTIVE,
                        nowNanos,
                        "attack_completed"
                    )
                    if (!translatedAudioQueued) startGap(nowNanos)
                }
            }
            AssistantTranslationDuckingState.TRANSLATION_ACTIVE -> {
                if (!translatedAudioQueued) startGap(nowNanos)
            }
            AssistantTranslationDuckingState.GAP_HOLD -> {
                if (translatedAudioQueued) {
                    transition(
                        AssistantTranslationDuckingState.TRANSLATION_ACTIVE,
                        nowNanos,
                        "translated_queue_refilled"
                    )
                    gapStartedAtNanos = Long.MIN_VALUE
                } else {
                    maybeStartRelease(nowNanos)
                }
            }
            AssistantTranslationDuckingState.RELEASE -> {
                if (elapsed(nowNanos, stateStartedAtNanos) >= timings.releaseNanos) {
                    transition(
                        AssistantTranslationDuckingState.ORIGINAL_ONLY,
                        nowNanos,
                        "release_completed"
                    )
                    responseDoneAtNanos = Long.MIN_VALUE
                }
            }
        }
        return decision(nowNanos)
    }

    private fun startGap(nowNanos: Long) {
        gapStartedAtNanos = nowNanos
        transition(
            AssistantTranslationDuckingState.GAP_HOLD,
            nowNanos,
            "translated_queue_drained"
        )
    }

    private fun maybeStartRelease(nowNanos: Long) {
        val releaseReason = when {
            responseDoneAtNanos != Long.MIN_VALUE -> {
                val boundaryReadyAt = maxOf(gapStartedAtNanos, responseDoneAtNanos)
                if (elapsed(nowNanos, boundaryReadyAt) >= timings.completionTailNanos) {
                    "response_done_tail_elapsed"
                } else {
                    null
                }
            }
            responseBoundarySupported &&
                elapsed(nowNanos, gapStartedAtNanos) >= timings.responseWatchdogNanos ->
                "response_done_watchdog_elapsed"
            !responseBoundarySupported &&
                elapsed(nowNanos, gapStartedAtNanos) >= timings.fallbackHoldNanos ->
                "fallback_hold_elapsed"
            else -> null
        }
        if (releaseReason != null) {
            transition(
                AssistantTranslationDuckingState.RELEASE,
                nowNanos,
                releaseReason
            )
        }
    }

    private fun decision(nowNanos: Long): AssistantTranslationDuckingDecision =
        AssistantTranslationDuckingDecision(
            state = state,
            reason = reason,
            attackProgress = if (state == AssistantTranslationDuckingState.ATTACK) {
                progress(nowNanos, stateStartedAtNanos, timings.attackNanos)
            } else {
                1f
            },
            releaseProgress = if (state == AssistantTranslationDuckingState.RELEASE) {
                progress(nowNanos, stateStartedAtNanos, timings.releaseNanos)
            } else {
                0f
            }
        )

    private fun transition(
        next: AssistantTranslationDuckingState,
        nowNanos: Long,
        transitionReason: String
    ) {
        if (state == next) return
        state = next
        stateStartedAtNanos = nowNanos
        reason = transitionReason
    }

    private fun progress(nowNanos: Long, startedAtNanos: Long, durationNanos: Long): Float {
        if (durationNanos <= 0L) return 1f
        return (elapsed(nowNanos, startedAtNanos).toDouble() / durationNanos)
            .coerceIn(0.0, 1.0)
            .toFloat()
    }

    private fun elapsed(nowNanos: Long, startedAtNanos: Long): Long =
        (nowNanos - startedAtNanos).coerceAtLeast(0L)
}
