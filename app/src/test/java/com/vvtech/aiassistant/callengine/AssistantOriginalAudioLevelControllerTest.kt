package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt

class AssistantOriginalAudioLevelControllerTest {
    @Test
    fun `quiet original is raised to configured rms ratio`() {
        val decision = AssistantOriginalAudioLevelController(0.4f).nextGain(
            original = alternatingFrame(1_000),
            translated = alternatingFrame(10_000),
            translationWindowActive = true
        )

        assertEquals(0.4, contributionRatio(1_000, 10_000, decision.appliedGain), 0.02)
        assertTrue(decision.balanced)
    }

    @Test
    fun `loud original is reduced to configured rms ratio`() {
        val decision = AssistantOriginalAudioLevelController(0.4f).nextGain(
            original = alternatingFrame(20_000),
            translated = alternatingFrame(5_000),
            translationWindowActive = true
        )

        assertEquals(0.4, contributionRatio(20_000, 5_000, decision.appliedGain), 0.02)
        assertTrue(decision.balanced)
    }

    @Test
    fun `silence does not trigger dynamic boost`() {
        val decision = AssistantOriginalAudioLevelController(0.7f).nextGain(
            original = alternatingFrame(10),
            translated = alternatingFrame(10_000),
            translationWindowActive = true
        )

        assertEquals(0.7f, decision.appliedGain, 0.001f)
        assertFalse(decision.balanced)
        assertFalse(decision.gainLimited)
    }

    @Test
    fun `zero ratio removes original for the whole translation window`() {
        val controller = AssistantOriginalAudioLevelController(0f)

        assertEquals(
            0f,
            controller.nextGain(
                original = alternatingFrame(10_000),
                translated = alternatingFrame(5_000),
                translationWindowActive = true
            ).appliedGain,
            0f
        )
        assertEquals(
            0f,
            controller.nextGain(
                original = alternatingFrame(10_000),
                translated = null,
                translationWindowActive = true
            ).appliedGain,
            0f
        )
    }

    @Test
    fun `one hundred percent targets equal rms`() {
        val decision = AssistantOriginalAudioLevelController(1f).nextGain(
            original = alternatingFrame(5_000),
            translated = alternatingFrame(10_000),
            translationWindowActive = true
        )

        assertEquals(1.0, contributionRatio(5_000, 10_000, decision.appliedGain), 0.02)
    }

    @Test
    fun `boost is capped when original is much quieter`() {
        val decision = AssistantOriginalAudioLevelController(1f).nextGain(
            original = alternatingFrame(200),
            translated = alternatingFrame(20_000),
            translationWindowActive = true
        )

        assertEquals(8f, decision.appliedGain, 0.001f)
        assertTrue(decision.gainLimited)
    }

    @Test
    fun `custom gain cap prevents original from exceeding configured mix ratio`() {
        val decision = AssistantOriginalAudioLevelController(
            targetOriginalRatio = 0.1f,
            pureOriginalGain = 0.1f,
            maxOriginalGain = 0.1f
        ).nextGain(
            original = alternatingFrame(200),
            translated = alternatingFrame(20_000),
            translationWindowActive = true
        )

        assertEquals(0.1f, decision.appliedGain, 0.001f)
        assertTrue(decision.gainLimited)
    }

    @Test
    fun `boost changes are smoothed after first balanced frame`() {
        val controller = AssistantOriginalAudioLevelController(0.4f)
        val first = controller.nextGain(
            original = alternatingFrame(20_000),
            translated = alternatingFrame(5_000),
            translationWindowActive = true
        )
        val second = controller.nextGain(
            original = alternatingFrame(1_000),
            translated = alternatingFrame(10_000),
            translationWindowActive = true
        )

        assertTrue(second.appliedGain > first.appliedGain)
        assertTrue(second.appliedGain < second.targetGain)
    }

    @Test
    fun `translation window end restores configured pure original gain`() {
        val controller = AssistantOriginalAudioLevelController(
            targetOriginalRatio = 0.4f,
            pureOriginalGain = 0.6f
        )
        controller.nextGain(
            original = alternatingFrame(20_000),
            translated = alternatingFrame(5_000),
            translationWindowActive = true
        )

        val restored = controller.nextGain(
            original = alternatingFrame(20_000),
            translated = null,
            translationWindowActive = false
        )

        assertEquals(0.6f, restored.appliedGain, 0f)
        assertFalse(restored.balanced)
    }

    private fun alternatingFrame(amplitude: Int): ShortArray =
        ShortArray(320) { if (it % 2 == 0) amplitude.toShort() else (-amplitude).toShort() }

    private fun contributionRatio(
        originalAmplitude: Int,
        translatedAmplitude: Int,
        gain: Float
    ): Double {
        val original = alternatingFrame(originalAmplitude)
        val translated = alternatingFrame(translatedAmplitude)
        return rms(original) * gain / rms(translated)
    }

    private fun rms(samples: ShortArray): Double =
        sqrt(samples.sumOf { it.toDouble() * it.toDouble() } / samples.size)
}
