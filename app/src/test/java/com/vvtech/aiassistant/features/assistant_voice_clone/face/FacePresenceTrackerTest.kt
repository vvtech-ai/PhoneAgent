package com.vvtech.aiassistant.features.assistant_voice_clone.face

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FacePresenceTrackerTest {

    @Test
    fun `samples at 250ms and accepts single face ratio at least 80 percent`() {
        val tracker = FacePresenceTracker()
        tracker.onCameraReady()
        tracker.onSample(0, 1)
        assertTrue(tracker.startRecording(0))

        tracker.onSample(0, 1)
        tracker.onSample(100, 0)
        tracker.onSample(250, 1)
        tracker.onSample(500, 1)
        tracker.onSample(750, 1)
        tracker.onSample(1000, 0)

        val result = tracker.finish(1000)
        assertNull(result.failure)
        assertEquals(5, result.summary.sampledFrames)
        assertEquals(4, result.summary.singleFaceFrames)
        assertEquals(0.8, result.summary.singleFaceRatio, 0.0001)
    }

    @Test
    fun `multiple faces fail immediately`() {
        val tracker = recordingTracker()

        val snapshot = tracker.onSample(250, 2)

        assertEquals(FacePresenceFailure.MULTIPLE_FACES, snapshot.failure)
        assertTrue(snapshot.summary.multipleFaceDetected)
    }

    @Test
    fun `missing face fails only after more than 1000ms`() {
        val tracker = recordingTracker()
        tracker.onSample(250, 0)
        tracker.onSample(1250, 0)
        assertNull(tracker.snapshot.failure)

        val failed = tracker.onSample(1500, 0)

        assertEquals(FacePresenceFailure.FACE_MISSING, failed.failure)
        assertTrue(failed.summary.maxMissingDurationMs > 1000)
    }

    @Test
    fun `finish rejects ratio below 80 percent`() {
        val tracker = recordingTracker()
        tracker.onSample(250, 1)
        tracker.onSample(500, 1)
        tracker.onSample(750, 1)
        tracker.onSample(1000, 0)
        tracker.onSample(1250, 0)

        val result = tracker.finish(1250)

        assertEquals(FacePresenceFailure.LOW_SINGLE_FACE_RATIO, result.failure)
        assertFalse(result.summary.multipleFaceDetected)
    }

    @Test
    fun `watchdog rejects recording when analyzer produces no frame for more than 1000ms`() {
        val tracker = recordingTracker()
        tracker.onSample(250, 1)

        val result = tracker.onWatchdogTick(1_251)

        assertEquals(FacePresenceFailure.ANALYSIS_STALLED, result.failure)
        assertEquals(1_001, result.summary.maxFrameGapMs)
    }

    @Test
    fun `finish rejects a stale final camera frame`() {
        val tracker = recordingTracker()
        tracker.onSample(250, 1)

        val result = tracker.finish(1_251)

        assertEquals(FacePresenceFailure.ANALYSIS_STALLED, result.failure)
    }

    @Test
    fun `new collection resets metrics but preserves live camera session`() {
        val tracker = recordingTracker()
        tracker.onSample(250, 1)
        tracker.cancelRecording()

        val result = tracker.prepareCollection()

        assertTrue(result.cameraReady)
        assertEquals(1, result.currentFaceCount)
        assertTrue(result.readyToRecord)
        assertEquals(0, result.summary.sampledFrames)
        assertNull(result.failure)
    }

    private fun recordingTracker(): FacePresenceTracker = FacePresenceTracker().also { tracker ->
        tracker.onCameraReady()
        tracker.onSample(0, 1)
        assertTrue(tracker.startRecording(0))
    }
}
