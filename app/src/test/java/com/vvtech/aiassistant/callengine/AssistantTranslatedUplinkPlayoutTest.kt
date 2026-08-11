package com.vvtech.aiassistant.callengine

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslatedUplinkPlayoutTest {
    @Test
    fun `frame queue preserves samples across irregular provider chunks`() {
        val queue = AssistantTranslatedAudioFrameQueue(
            frameSamples = 4,
            maxQueuedSamples = 20
        )

        assertTrue(queue.enqueue(shortArrayOf(1, 2, 3)).accepted)
        assertTrue(queue.enqueue(shortArrayOf(4, 5, 6, 7, 8)).accepted)

        assertArrayEquals(shortArrayOf(1, 2, 3, 4), queue.pollFrame())
        assertArrayEquals(shortArrayOf(5, 6, 7, 8), queue.pollFrame())
        assertEquals(0, queue.queuedSamples())
    }

    @Test
    fun `frame queue rejects overflow without disturbing queued audio`() {
        val queue = AssistantTranslatedAudioFrameQueue(
            frameSamples = 4,
            maxQueuedSamples = 8
        )

        assertTrue(queue.enqueue(shortArrayOf(1, 2, 3, 4)).accepted)
        assertFalse(queue.enqueue(ShortArray(5)).accepted)

        assertArrayEquals(shortArrayOf(1, 2, 3, 4), queue.pollFrame())
    }

    @Test
    fun `partial tail is not reported as playable translated audio`() {
        val queue = AssistantTranslatedAudioFrameQueue(
            frameSamples = 4,
            maxQueuedSamples = 20
        )

        assertTrue(queue.enqueue(shortArrayOf(1, 2, 3)).accepted)

        assertFalse(queue.hasPlayableFrame())
        assertEquals(3, queue.queuedSamples())
        assertEquals(null, queue.pollFrame())
    }

    @Test
    fun `rtp pacer spaces consecutive frames by twenty milliseconds`() {
        var now = 1_000_000_000L
        val delays = mutableListOf<Long>()
        val pacer = AssistantRtpFramePacer(
            nanoTime = { now },
            parkNanos = { delay ->
                delays += delay
                now += delay
            }
        )

        pacer.paceBeforeSend()
        pacer.paceBeforeSend()
        pacer.paceBeforeSend()

        assertEquals(listOf(20_000_000L, 20_000_000L), delays)
    }

    @Test
    fun `playout fills underflow then resumes after buffering and closes`() {
        val logs = Collections.synchronizedList(mutableListOf<String>())
        val sent = Collections.synchronizedList(mutableListOf<ShortArray>())
        val underflow = CountDownLatch(1)
        val fillerSent = CountDownLatch(1)
        val resumed = CountDownLatch(1)
        val resumedAudioSent = CountDownLatch(1)
        val playout = AssistantTranslatedUplinkPlayout(
            traceId = "trace-test",
            sendFrame = { frame ->
                sent += frame.copyOf()
                if (frame.all { it.toInt() == 0 }) fillerSent.countDown()
                if (frame.any { it.toInt() == 800 }) resumedAudioSent.countDown()
            },
            onFailure = { throw AssertionError(it) },
            logger = { line ->
                logs += line
                if (line.contains("event=underflow")) underflow.countDown()
                if (line.contains("event=resume_ready")) resumed.countDown()
            }
        )

        playout.start()
        playout.enqueue(ShortArray(2_560) { 700 })
        assertTrue(underflow.await(2, TimeUnit.SECONDS))
        assertTrue(sent.any { frame -> frame.any { it.toInt() == 700 } })
        assertTrue(fillerSent.await(1, TimeUnit.SECONDS))

        playout.enqueue(ShortArray(2_560) { 800 })
        assertTrue(resumed.await(2, TimeUnit.SECONDS))
        assertTrue(resumedAudioSent.await(1, TimeUnit.SECONDS))
        playout.close()
        val framesAtClose = sent.size
        Thread.sleep(60)

        assertEquals(framesAtClose, sent.size)
        assertTrue(logs.any { it.contains("traceId=trace-test event=buffer_ready") })
        assertTrue(logs.any { it.contains("event=closed") })
    }
}
