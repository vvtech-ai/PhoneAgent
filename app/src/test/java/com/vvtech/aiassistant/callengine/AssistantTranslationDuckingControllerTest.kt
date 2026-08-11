package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslationDuckingControllerTest {
    @Test
    fun `fallback provider holds a translated gap for seven hundred milliseconds`() {
        val controller = AssistantTranslationDuckingController(
            responseBoundarySupported = false
        )

        controller.onTranslatedAudio(ms(0))
        assertEquals(AssistantTranslationDuckingState.ATTACK, controller.next(ms(0), true).state)
        assertEquals(
            AssistantTranslationDuckingState.TRANSLATION_ACTIVE,
            controller.next(ms(40), true).state
        )
        assertEquals(
            AssistantTranslationDuckingState.GAP_HOLD,
            controller.next(ms(100), false).state
        )
        assertEquals(
            AssistantTranslationDuckingState.GAP_HOLD,
            controller.next(ms(799), false).state
        )
        assertEquals(
            AssistantTranslationDuckingState.RELEASE,
            controller.next(ms(800), false).state
        )
    }

    @Test
    fun `reliable response waits for done and completion tail after queue drains`() {
        val controller = AssistantTranslationDuckingController(
            responseBoundarySupported = true
        )

        controller.onTranslatedAudio(ms(0))
        controller.next(ms(40), true)
        controller.next(ms(100), false)
        assertEquals(
            AssistantTranslationDuckingState.GAP_HOLD,
            controller.next(ms(299), false).state
        )

        controller.onResponseDone(ms(300))

        assertEquals(
            AssistantTranslationDuckingState.GAP_HOLD,
            controller.next(ms(499), false).state
        )
        assertEquals(
            AssistantTranslationDuckingState.RELEASE,
            controller.next(ms(500), false).state
        )
    }

    @Test
    fun `missing reliable boundary releases through watchdog`() {
        val controller = AssistantTranslationDuckingController(
            responseBoundarySupported = true
        )

        controller.onTranslatedAudio(ms(0))
        controller.next(ms(40), true)
        controller.next(ms(100), false)

        assertEquals(
            AssistantTranslationDuckingState.GAP_HOLD,
            controller.next(ms(1_599), false).state
        )
        assertEquals(
            AssistantTranslationDuckingState.RELEASE,
            controller.next(ms(1_600), false).state
        )
    }

    @Test
    fun `release progresses for three hundred fifty milliseconds`() {
        val controller = AssistantTranslationDuckingController(
            responseBoundarySupported = false
        )

        controller.onTranslatedAudio(ms(0))
        controller.next(ms(40), true)
        controller.next(ms(100), false)
        val releaseStart = controller.next(ms(800), false)
        val releaseMiddle = controller.next(ms(975), false)
        val releaseEnd = controller.next(ms(1_150), false)

        assertEquals(0f, releaseStart.releaseProgress, 0.001f)
        assertEquals(0.5f, releaseMiddle.releaseProgress, 0.001f)
        assertEquals(AssistantTranslationDuckingState.ORIGINAL_ONLY, releaseEnd.state)
    }

    @Test
    fun `new translated audio cancels release and starts attack again`() {
        val controller = AssistantTranslationDuckingController(
            responseBoundarySupported = false
        )

        controller.onTranslatedAudio(ms(0))
        controller.next(ms(40), true)
        controller.next(ms(100), false)
        controller.next(ms(800), false)
        controller.next(ms(900), false)

        controller.onTranslatedAudio(ms(910))
        val resumed = controller.next(ms(910), true)

        assertEquals(AssistantTranslationDuckingState.ATTACK, resumed.state)
        assertEquals("translated_audio_resumed", resumed.reason)
        assertTrue(resumed.attackProgress < 0.01f)
    }

    @Test
    fun `played frame closes enqueue race without clearing an active response`() {
        val controller = AssistantTranslationDuckingController(
            responseBoundarySupported = true
        )

        controller.ensureTranslatedAudioActive(ms(0))
        assertEquals(
            AssistantTranslationDuckingState.ATTACK,
            controller.next(ms(0), true).state
        )
        controller.next(ms(40), true)
        controller.onResponseDone(ms(50))
        controller.ensureTranslatedAudioActive(ms(60))
        controller.next(ms(100), false)

        assertEquals(
            AssistantTranslationDuckingState.RELEASE,
            controller.next(ms(300), false).state
        )
    }

    private fun ms(value: Long): Long = value * 1_000_000L
}
