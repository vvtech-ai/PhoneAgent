package com.vvtech.aiassistant.features.assistant_voice

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceRecognizedInputDedupTrackerTest {
    @Test
    fun sameInputGenerationDropsRepeatedFinal() {
        val tracker = VoiceRecognizedInputDedupTracker()

        tracker.beginInput()
        tracker.markAccepted("可以。")

        assertTrue(tracker.isDuplicateInCurrentInput("可以"))
    }

    @Test
    fun newInputGenerationAllowsSameTextAfterFailedTurn() {
        val tracker = VoiceRecognizedInputDedupTracker()

        tracker.beginInput()
        tracker.markAccepted("可以。")
        tracker.beginInput()

        assertFalse(tracker.isDuplicateInCurrentInput("可以。"))
    }

    @Test
    fun resetClearsAcceptedInput() {
        val tracker = VoiceRecognizedInputDedupTracker()

        tracker.beginInput()
        tracker.markAccepted("继续。")
        tracker.reset()

        assertFalse(tracker.isDuplicateInCurrentInput("继续。"))
    }
}
