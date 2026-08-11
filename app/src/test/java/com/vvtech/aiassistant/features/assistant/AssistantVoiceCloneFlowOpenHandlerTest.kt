package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentState
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresenceSnapshot
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AssistantVoiceCloneFlowOpenHandlerTest {

    @Test
    fun `missing status is recovered and opens flow in same click`() = runTest {
        val state = runtimeState()
        var opened = false
        val handler = AssistantVoiceCloneFlowOpenHandler(
            scope = this,
            loadStatus = { availableStatus() },
            state = state
        )

        handler.open(
            resetRecording = false,
            onAvailable = { opened = true },
            onMessage = {}
        )
        advanceUntilIdle()

        assertTrue(opened)
        assertNotNull(state.status.value)
        assertEquals(false, state.loading.value)
    }

    @Test
    fun `failed recovery can be retried immediately from identity entry`() = runTest {
        val state = runtimeState()
        var attempts = 0
        var opened = false
        val messages = mutableListOf<String>()
        val handler = AssistantVoiceCloneFlowOpenHandler(
            scope = this,
            loadStatus = {
                attempts += 1
                if (attempts == 1) error("HTTP 401")
                availableStatus()
            },
            state = state
        )

        handler.open(false, { opened = true }, messages::add)
        advanceUntilIdle()
        handler.open(false, { opened = true }, messages::add)
        advanceUntilIdle()

        assertEquals(2, attempts)
        assertTrue(opened)
        assertEquals(
            "身份认证凭证恢复未成功，请点击身份认证重试",
            messages.first()
        )
    }

    private fun runtimeState() = AssistantVoiceCloneRuntimeState(
        guideSkipped = mutableStateOf(false),
        guideDisabled = mutableStateOf(false),
        forceGuide = mutableStateOf(false),
        showGuide = mutableStateOf(false),
        status = mutableStateOf(null),
        scripts = mutableStateOf<List<VoiceCloneScriptItem>>(emptyList()),
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
        submissionState = mutableStateOf(VoiceCloneSubmissionState.IDLE),
        currentScriptIndex = mutableStateOf(0),
        playingScriptId = mutableStateOf(null),
        facePresence = mutableStateOf(FacePresenceSnapshot())
    )

    private fun availableStatus() = VoiceCloneStatusResponse(
        accountId = "phone-13800138000",
        status = "NOT_CREATED",
        active = false,
        speakerId = "",
        displayName = "我的声音",
        sampleCount = 0,
        lastError = "",
        updatedAt = null,
        enrollmentAvailable = true
    )
}
