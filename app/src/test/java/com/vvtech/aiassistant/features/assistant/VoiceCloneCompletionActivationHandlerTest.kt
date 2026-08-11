package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentState
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceSnapshot
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneCompletionActivationHandlerTest {

    @Test
    fun `ready clone submits selected consent and navigates only after activation succeeds`() {
        val state = runtimeState(status(active = false))
        var submittedConsent: Boolean? = null
        var navigated = false
        val messages = mutableListOf<String>()
        val handler = VoiceCloneCompletionActivationHandler(state) { consent, callback ->
            submittedConsent = consent
            callback(Result.success(status(active = true)))
        }

        handler.activate(
            improvementConsent = true,
            onMessage = messages::add,
            onActivated = { navigated = true }
        )

        assertEquals(true, submittedConsent)
        assertTrue(state.status.value?.active == true)
        assertFalse(state.actionLoading.value)
        assertTrue(navigated)
        assertEquals(listOf("已切换为我的克隆音色"), messages)
    }

    @Test
    fun `activation failure keeps completion page and exposes error`() {
        val state = runtimeState(status(active = false))
        var navigated = false
        val handler = VoiceCloneCompletionActivationHandler(state) { _, callback ->
            callback(Result.failure(IllegalStateException("授权保存失败")))
        }

        handler.activate(true, {}, { navigated = true })

        assertFalse(navigated)
        assertFalse(state.actionLoading.value)
        assertEquals("授权保存失败", state.error.value)
    }

    @Test
    fun `activation response cannot erase previously confirmed enrollment capability`() {
        val state = runtimeState(status(active = false, enrollmentAvailable = true))
        val handler = VoiceCloneCompletionActivationHandler(state) { _, callback ->
            callback(
                Result.success(
                    status(active = true, enrollmentAvailable = false)
                )
            )
        }

        handler.activate(true, {}, {})

        assertTrue(state.status.value?.active == true)
        assertTrue(state.status.value?.enrollmentAvailable == true)
    }

    private fun runtimeState(status: VoiceCloneStatusResponse) =
        AssistantVoiceCloneRuntimeState(
            guideSkipped = mutableStateOf(false),
            guideDisabled = mutableStateOf(false),
            forceGuide = mutableStateOf(false),
            showGuide = mutableStateOf(false),
            status = mutableStateOf(status),
            scripts = mutableStateOf(emptyList()),
            scriptsVersion = mutableStateOf(""),
            loading = mutableStateOf(false),
            uploading = mutableStateOf(false),
            actionLoading = mutableStateOf(false),
            error = mutableStateOf(null),
            samples = mutableStateOf(emptyMap()),
            recordingScriptId = mutableStateOf(null),
            pendingRecordScriptId = mutableStateOf(null),
            rerecordMode = mutableStateOf(false),
            enrollment = mutableStateOf(VoiceCloneEnrollmentState()),
            submissionState = mutableStateOf(VoiceCloneSubmissionState.READY),
            currentScriptIndex = mutableStateOf(0),
            playingScriptId = mutableStateOf(null),
            facePresence = mutableStateOf(FacePresenceSnapshot())
        )

    private fun status(
        active: Boolean,
        enrollmentAvailable: Boolean = true
    ) = VoiceCloneStatusResponse(
        accountId = "account-a",
        status = "READY",
        active = active,
        speakerId = "voice-a",
        displayName = "我的声音",
        sampleCount = 1,
        lastError = "",
        updatedAt = "2026-07-23T21:00:00",
        enrollmentAvailable = enrollmentAvailable
    )
}
