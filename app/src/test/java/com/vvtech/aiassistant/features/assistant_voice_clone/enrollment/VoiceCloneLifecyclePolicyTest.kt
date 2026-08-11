package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneLifecyclePolicyTest {
    @Test
    fun `background only interrupts unfinished collection`() {
        assertTrue(shouldInterruptVoiceCloneOnBackground(VoiceCloneSubmissionState.IDLE))
        assertTrue(shouldInterruptVoiceCloneOnBackground(VoiceCloneSubmissionState.PROCESSING))
        assertFalse(shouldInterruptVoiceCloneOnBackground(VoiceCloneSubmissionState.READY))
    }

    @Test
    fun `foreground completes and exits only from ready result`() {
        assertFalse(shouldCompleteVoiceCloneOnForeground(VoiceCloneSubmissionState.IDLE))
        assertFalse(shouldCompleteVoiceCloneOnForeground(VoiceCloneSubmissionState.PROCESSING))
        assertTrue(shouldCompleteVoiceCloneOnForeground(VoiceCloneSubmissionState.READY))
    }
}
