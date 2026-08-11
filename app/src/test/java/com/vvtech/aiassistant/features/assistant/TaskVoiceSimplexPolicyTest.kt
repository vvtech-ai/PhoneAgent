package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskVoiceSimplexPolicyTest {
    @Test
    fun neverArmsAsrDuringAssistantPlayback() {
        assertFalse(shouldArmTaskAsrDuringSimplexPlayback())
    }

    @Test
    fun ignoresAsrEventsWhileAnyAssistantPlaybackIsActive() {
        assertTrue(
            shouldIgnoreTaskAsrEventDuringSimplexPlayback(
                apiTtsPlaying = true,
                localTtsSpeaking = false,
                localTtsPlaying = false
            )
        )
        assertTrue(
            shouldIgnoreTaskAsrEventDuringSimplexPlayback(
                apiTtsPlaying = false,
                localTtsSpeaking = true,
                localTtsPlaying = false
            )
        )
        assertTrue(
            shouldIgnoreTaskAsrEventDuringSimplexPlayback(
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                localTtsPlaying = true
            )
        )
    }

    @Test
    fun acceptsAsrEventsOnlyAfterPlaybackEnds() {
        assertFalse(
            shouldIgnoreTaskAsrEventDuringSimplexPlayback(
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                localTtsPlaying = false
            )
        )
    }

    @Test
    fun doesNotResumeAsrAfterPlaybackEvenForActiveVoiceTurns() {
        assertFalse(
            shouldResumeTaskAsrAfterSimplexPlayback(
                isVoiceChannel = true,
                asrListening = false,
                recording = false,
                manuallyPaused = false,
                backgroundPaused = false,
                terminalCallResult = false
            )
        )
    }

    @Test
    fun doesNotResumeAsrForPausedOrTerminalPlayback() {
        assertFalse(
            shouldResumeTaskAsrAfterSimplexPlayback(
                isVoiceChannel = true,
                asrListening = false,
                recording = false,
                manuallyPaused = true,
                backgroundPaused = false,
                terminalCallResult = false
            )
        )
        assertFalse(
            shouldResumeTaskAsrAfterSimplexPlayback(
                isVoiceChannel = true,
                asrListening = false,
                recording = false,
                manuallyPaused = false,
                backgroundPaused = false,
                terminalCallResult = true
            )
        )
    }
}
