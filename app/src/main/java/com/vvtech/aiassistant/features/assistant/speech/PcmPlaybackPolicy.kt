package com.vvtech.aiassistant.features.assistant.speech

internal data class PcmPlaybackPolicy(
    val sampleRate: Int,
    val startGuardMs: Int,
    val betweenSegmentGuardMs: Int,
    val endPaddingMs: Int,
    val idleGraceMs: Long,
    val drainSafetyMs: Long,
    val maxDrainWaitMs: Long
) {
    val bytesPerFrame: Int = PCM_BYTES_PER_FRAME

    fun frameBytes(frameMs: Int = PCM_FRAME_MS): Int =
        sampleRate * bytesPerFrame * frameMs / 1_000

    fun bytesForMs(durationMs: Int): Int =
        sampleRate * bytesPerFrame * durationMs / 1_000

    fun durationMsForBytes(byteCount: Int): Long =
        if (byteCount <= 0) 0L else byteCount.toLong() * 1_000L / (sampleRate * bytesPerFrame)
}

internal fun pcmPlaybackPolicyFor(format: TtsAudioFormat): PcmPlaybackPolicy = when (format) {
    TtsAudioFormat.Pcm24k16BitMono -> PcmPlaybackPolicy(
        sampleRate = PCM_24K_SAMPLE_RATE,
        startGuardMs = 320,
        betweenSegmentGuardMs = 0,
        endPaddingMs = 60,
        idleGraceMs = 240L,
        drainSafetyMs = 120L,
        maxDrainWaitMs = 480L
    )

    else -> PcmPlaybackPolicy(
        sampleRate = PCM_16K_SAMPLE_RATE,
        startGuardMs = 640,
        betweenSegmentGuardMs = 80,
        endPaddingMs = 80,
        idleGraceMs = 240L,
        drainSafetyMs = 160L,
        maxDrainWaitMs = 640L
    )
}

internal const val PCM_16K_SAMPLE_RATE = 16_000
internal const val PCM_24K_SAMPLE_RATE = 24_000
internal const val PCM_BYTES_PER_FRAME = 2
internal const val PCM_FRAME_MS = 40
