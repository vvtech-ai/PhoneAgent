package com.vvtech.aiassistant.callengine

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantDoubaoTranslationAudioCompletionGateTest {
    @Test
    fun `translation end emits completion after debounce`() {
        val completed = CountDownLatch(1)
        val gate = AssistantDoubaoTranslationAudioCompletionGate(
            speaker = "local",
            completionDelayMs = 20L,
            onCompleted = { completed.countDown() }
        )

        gate.onTranslationEnd()

        assertTrue(completed.await(500, TimeUnit.MILLISECONDS))
        gate.close()
    }

    @Test
    fun `tts chunk after translation end delays completion until audio settles`() {
        val completed = CountDownLatch(1)
        val gate = AssistantDoubaoTranslationAudioCompletionGate(
            speaker = "remote",
            completionDelayMs = 80L,
            onCompleted = { completed.countDown() }
        )

        gate.onTranslationEnd()
        Thread.sleep(40L)
        gate.onAudioChunk()

        assertFalse(completed.await(30, TimeUnit.MILLISECONDS))
        assertTrue(completed.await(500, TimeUnit.MILLISECONDS))
        gate.close()
    }

    @Test
    fun `new translation start cancels pending completion`() {
        val completed = CountDownLatch(1)
        val gate = AssistantDoubaoTranslationAudioCompletionGate(
            speaker = "local",
            completionDelayMs = 40L,
            onCompleted = { completed.countDown() }
        )

        gate.onTranslationEnd()
        gate.onTranslationStart()

        assertFalse(completed.await(120, TimeUnit.MILLISECONDS))
        gate.close()
    }
}
