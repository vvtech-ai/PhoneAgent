package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneAvailabilityPolicyTest {
    @Test
    fun `new enrollment entry requires server capability`() {
        val unavailable = status(enrollmentAvailable = false)
        val available = status(enrollmentAvailable = true)

        assertFalse(VoiceCloneAvailabilityPolicy.canEnroll(unavailable))
        assertFalse(VoiceCloneAvailabilityPolicy.shouldShowEntry(unavailable, hasClone = false))
        assertTrue(VoiceCloneAvailabilityPolicy.canEnroll(available))
        assertTrue(VoiceCloneAvailabilityPolicy.shouldShowEntry(available, hasClone = false))
        assertTrue(VoiceCloneAvailabilityPolicy.shouldShowEntry(unavailable, hasClone = true))
    }

    @Test
    fun `missing status reports load failure instead of missing environment configuration`() {
        assertEquals(
            "身份认证凭证恢复未成功，请点击身份认证重试",
            VoiceCloneAvailabilityPolicy.enrollmentUnavailableMessage(status = null)
        )
    }

    @Test
    fun `server capability unavailable keeps environment configuration message`() {
        assertEquals(
            "当前环境未配置实名认证或朗读校验，暂不可采集声音",
            VoiceCloneAvailabilityPolicy.enrollmentUnavailableMessage(
                status(enrollmentAvailable = false)
            )
        )
    }

    private fun status(enrollmentAvailable: Boolean) = VoiceCloneStatusResponse(
        accountId = "phone-13800000000",
        status = "NOT_CREATED",
        active = false,
        speakerId = "",
        displayName = "我的声音",
        sampleCount = 0,
        lastError = "",
        updatedAt = null,
        enrollmentAvailable = enrollmentAvailable
    )
}
