package com.vvtech.aiassistant.features.assistant.speech

import org.junit.Assert.assertEquals
import org.junit.Test

class PcmPlaybackPolicyTest {

    @Test
    fun qwen24kPolicyUsesLowLatencyStreamingSettings() {
        val policy = pcmPlaybackPolicyFor(TtsAudioFormat.Pcm24k16BitMono)

        assertEquals(24_000, policy.sampleRate)
        assertEquals(320, policy.startGuardMs)
        assertEquals(0, policy.betweenSegmentGuardMs)
        assertEquals(240L, policy.idleGraceMs)
        assertEquals(120L, policy.drainSafetyMs)
        assertEquals(480L, policy.maxDrainWaitMs)
        assertEquals(15_360, policy.bytesForMs(320))
        assertEquals(5_760, policy.frameBytes(120))
        assertEquals(500L, policy.durationMsForBytes(24_000))
    }

    @Test
    fun legacy16kPolicyKeepsExistingPaddingSettings() {
        val policy = pcmPlaybackPolicyFor(TtsAudioFormat.Pcm16k16BitMono)

        assertEquals(16_000, policy.sampleRate)
        assertEquals(640, policy.startGuardMs)
        assertEquals(80, policy.betweenSegmentGuardMs)
        assertEquals(240L, policy.idleGraceMs)
        assertEquals(20_480, policy.bytesForMs(640))
    }
}
