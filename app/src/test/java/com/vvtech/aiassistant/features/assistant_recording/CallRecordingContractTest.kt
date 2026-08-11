package com.vvtech.aiassistant.features.assistant_recording

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.data.repository.recording.CallRecordingInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CallRecordingContractTest {
    @Test
    fun `recording duration counts down only while playing or paused`() {
        val ready = CallRecordingUiState(
            callId = "call-1",
            durationMillis = 65_000L,
        )

        assertEquals("01:05", ready.displayDuration())
        assertEquals(
            "00:53",
            ready.copy(
                playbackState = CallRecordingPlaybackState.Playing,
                playbackPositionMillis = 12_400L,
            ).displayDuration(),
        )
        assertEquals(
            "00:53",
            ready.copy(
                playbackState = CallRecordingPlaybackState.Paused,
                playbackPositionMillis = 12_400L,
            ).displayDuration(),
        )
        assertEquals(
            "01:05",
            ready.copy(
                playbackState = CallRecordingPlaybackState.Ended,
                playbackPositionMillis = 65_000L,
            ).displayDuration(),
        )
    }

    @Test
    fun `recording loading and failure use demo copy without countdown`() {
        val ready = CallRecordingUiState(
            callId = "call-1",
            durationMillis = 65_000L,
            playbackPositionMillis = 12_400L,
        )

        assertEquals(
            "录音加载中",
            ready.copy(playbackState = CallRecordingPlaybackState.Loading).displayDuration(),
        )
        assertEquals(
            "录音加载失败",
            ready.copy(playbackState = CallRecordingPlaybackState.Error).displayDuration(),
        )
    }

    @Test
    fun `recording control follows playback state`() {
        val ready = CallRecordingUiState(
            callId = "call-1",
        )

        assertEquals(CallRecordingControlIcon.Play, ready.controlIcon())
        assertEquals("播放本次电话录音", ready.controlClickLabel())

        val loading = ready.copy(playbackState = CallRecordingPlaybackState.Loading)
        assertEquals(CallRecordingControlIcon.Loading, loading.controlIcon())
        assertEquals("录音加载中", loading.controlClickLabel())

        val error = ready.copy(playbackState = CallRecordingPlaybackState.Error)
        assertEquals(CallRecordingControlIcon.Retry, error.controlIcon())
        assertEquals("录音加载失败，重新加载", error.controlClickLabel())

        val playing = ready.copy(playbackState = CallRecordingPlaybackState.Playing)
        assertEquals(CallRecordingControlIcon.Pause, playing.controlIcon())
        assertEquals("暂停本次电话录音", playing.controlClickLabel())
    }

    @Test
    fun `backend statuses only hydrate metadata and never change playback state`() {
        val loading = CallRecordingUiState(
            callId = "call-1",
            playbackState = CallRecordingPlaybackState.Loading,
            playbackPositionMillis = 4_000L,
            message = "录音加载中",
        )

        listOf("RECORDING", "PROCESSING", "READY", "FAILED", "EXPIRED", "LEGACY_MISSING")
            .forEach { status ->
                val hydrated = loading.withMetadata(
                    info(status).copy(
                        durationMillis = 65_000L,
                        contentType = "audio/wav",
                    )
                )

                assertEquals(CallRecordingPlaybackState.Loading, hydrated.playbackState)
                assertEquals(4_000L, hydrated.playbackPositionMillis)
                assertEquals("录音加载中", hydrated.message)
                assertEquals(65_000L, hydrated.durationMillis)
                assertEquals("audio/wav", hydrated.contentType)
            }
    }

    @Test
    fun `only recording and processing statuses continue metadata polling`() {
        assertTrue(info("RECORDING").isProcessing())
        assertTrue(info("PROCESSING").isProcessing())
        assertFalse(info("READY").isProcessing())
        assertFalse(info("FAILED").isProcessing())
        assertFalse(info("EXPIRED").isProcessing())
        assertFalse(info("LEGACY_MISSING").isProcessing())
    }

    @Test
    fun `unknown duration keeps normal interactive copy`() {
        val idle = CallRecordingUiState(callId = "call-1")

        assertEquals("点击播放", idle.displayDuration())
        assertEquals(
            "播放中",
            idle.copy(playbackState = CallRecordingPlaybackState.Playing).displayDuration(),
        )
        assertEquals(
            "已暂停",
            idle.copy(playbackState = CallRecordingPlaybackState.Paused).displayDuration(),
        )
    }

    @Test
    fun recordingAnchorUsesOnlyExplicitCallId() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "任务完成",
            detail = "已完成",
            metadata = mapOf("callId" to "call-1", "callAttemptId" to "attempt-1"),
        )
        val attemptOnly = result.copy(metadata = mapOf("callAttemptId" to "attempt-1"))

        assertEquals("call-1", callRecordingAnchor(result))
        assertNull(callRecordingAnchor(attemptOnly))
    }

    @Test
    fun newRecordingLoadInvalidatesPendingPlaybackRequest() {
        val requestVersion =
            CallRecordingPlaybackControl.capturePlaybackRequestVersion()

        assertTrue(CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion))

        val newRequestVersion = CallRecordingPlaybackControl.beginPlaybackRequest()

        assertFalse(CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion))
        assertTrue(CallRecordingPlaybackControl.isPlaybackRequestCurrent(newRequestVersion))
    }

    @Test
    fun voiceInputStopInvalidatesPendingPlaybackRequest() {
        val requestVersion =
            CallRecordingPlaybackControl.capturePlaybackRequestVersion()

        CallRecordingPlaybackControl.stopActiveForVoiceInput()

        assertFalse(CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion))
    }

    @Test
    fun hostStopInvalidatesPendingPlaybackRequest() {
        val requestVersion =
            CallRecordingPlaybackControl.capturePlaybackRequestVersion()

        CallRecordingPlaybackControl.stopActiveForHost("test_host_stop")

        assertFalse(CallRecordingPlaybackControl.isPlaybackRequestCurrent(requestVersion))
    }

    private fun info(status: String) = CallRecordingInfo(
        callId = "call-1",
        status = status,
        durationMillis = null,
        contentType = null,
    )
}
