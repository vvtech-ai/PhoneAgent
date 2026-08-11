package com.vvtech.aiassistant.features.assistant_voice_clone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneUploadPolicyTest {
    @Test
    fun `only ready status maps to completed UI`() {
        assertEquals(VoiceCloneSubmissionState.READY, VoiceCloneUploadPolicy.toSubmissionState("READY"))
        assertEquals(VoiceCloneSubmissionState.PROCESSING, VoiceCloneUploadPolicy.toSubmissionState("processing"))
        assertEquals(VoiceCloneSubmissionState.FAILED, VoiceCloneUploadPolicy.toSubmissionState("FAILED"))
        assertEquals(VoiceCloneSubmissionState.UNKNOWN, VoiceCloneUploadPolicy.toSubmissionState("NOT_CREATED"))
        assertEquals(VoiceCloneSubmissionState.UNKNOWN, VoiceCloneUploadPolicy.toSubmissionState(null))
        assertTrue(VoiceCloneUploadPolicy.isAcceptedProviderStatus("READY"))
        assertTrue(VoiceCloneUploadPolicy.isAcceptedProviderStatus("PROCESSING"))
        assertFalse(VoiceCloneUploadPolicy.isCompleted("PROCESSING"))
        assertTrue(VoiceCloneUploadPolicy.isCompleted("READY"))
    }
}
