package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantOriginalAudioMixPlayoutTest {
    @Test
    fun `pure original at one hundred percent remains unchanged`() {
        val original = shortArrayOf(1_000, -2_000)

        assertArrayEquals(
            original,
            AssistantOriginalAudioMixPlayout.mix(
                original = original,
                translated = null,
                resolvedOriginalGain = 0.5f,
                pureOriginalGain = 1f
            )
        )
    }

    @Test
    fun `pure original applies configured linear gain`() {
        val original = shortArrayOf(1_000, -2_000)

        assertArrayEquals(
            shortArrayOf(500, -1_000),
            AssistantOriginalAudioMixPlayout.mix(
                original = original,
                translated = null,
                resolvedOriginalGain = 0.5f,
                pureOriginalGain = 0.5f
            )
        )
        assertArrayEquals(
            shortArrayOf(0, 0),
            AssistantOriginalAudioMixPlayout.mix(
                original = original,
                translated = null,
                resolvedOriginalGain = 0.5f,
                pureOriginalGain = 0f
            )
        )
    }

    @Test
    fun `mix applies resolved original gain without reducing translation`() {
        val mixed = AssistantOriginalAudioMixPlayout.mix(
            original = shortArrayOf(1_000, -1_000),
            translated = shortArrayOf(2_000, 2_000),
            resolvedOriginalGain = 0.7f,
            pureOriginalGain = 0f
        )

        assertArrayEquals(shortArrayOf(2_700, 1_300), mixed)
    }

    @Test
    fun `mix preserves controller boost above unity without reducing translation`() {
        val mixed = AssistantOriginalAudioMixPlayout.mix(
            original = shortArrayOf(1_000, -1_000),
            translated = shortArrayOf(2_000, 2_000),
            resolvedOriginalGain = 4f
        )

        assertArrayEquals(shortArrayOf(6_000, -2_000), mixed)
    }

    @Test
    fun `mix saturates pcm16 range`() {
        val mixed = AssistantOriginalAudioMixPlayout.mix(
            original = shortArrayOf(Short.MAX_VALUE, Short.MIN_VALUE),
            translated = shortArrayOf(Short.MAX_VALUE, Short.MIN_VALUE),
            resolvedOriginalGain = 1f
        )

        assertEquals(Short.MAX_VALUE, mixed[0])
        assertEquals(Short.MIN_VALUE, mixed[1])
    }

    @Test
    fun `translation plays without an original frame`() {
        val translated = shortArrayOf(3_000, -4_000)

        assertArrayEquals(
            translated,
            AssistantOriginalAudioMixPlayout.mix(null, translated, 0.7f)
        )
    }

    @Test
    fun `tail window keeps original ducked between translated frames`() {
        val mixed = AssistantOriginalAudioMixPlayout.mix(
            original = shortArrayOf(1_000),
            translated = null,
            resolvedOriginalGain = 0.7f,
            translatedActive = true
        )

        assertArrayEquals(shortArrayOf(700), mixed)
    }

    @Test
    fun `configured zero removes current original while translation plays`() {
        assertArrayEquals(
            shortArrayOf(2_000),
            AssistantOriginalAudioMixPlayout.mix(
                original = shortArrayOf(1_000),
                translated = shortArrayOf(2_000),
                resolvedOriginalGain = 0f
            )
        )
    }

    @Test
    fun `configured full gain mixes current original at one hundred percent`() {
        assertArrayEquals(
            shortArrayOf(3_000),
            AssistantOriginalAudioMixPlayout.mix(
                original = shortArrayOf(1_000),
                translated = shortArrayOf(2_000),
                resolvedOriginalGain = 1f
            )
        )
    }

    @Test
    fun `rms diagnostics distinguish silence from audible pcm`() {
        assertEquals(
            Double.NEGATIVE_INFINITY,
            AssistantOriginalAudioMixPlayout.rmsDbfs(shortArrayOf(0, 0)),
            0.0
        )
        assertTrue(
            AssistantOriginalAudioMixPlayout.rmsDbfs(shortArrayOf(10_000, -10_000)) > -12.0
        )
    }
}
