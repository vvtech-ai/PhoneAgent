package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentStep
import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceCloneStepTitlePolicyTest {

    @Test
    fun `matches prototype step labels without declaring processing complete`() {
        assertEquals(
            "身份认证",
            VoiceCloneStepTitlePolicy.title(
                VoiceCloneEnrollmentStep.CONSENT,
                VoiceCloneSubmissionState.IDLE
            )
        )
        assertEquals(
            "1/3 填写信息",
            VoiceCloneStepTitlePolicy.title(
                VoiceCloneEnrollmentStep.IDENTITY,
                VoiceCloneSubmissionState.IDLE
            )
        )
        assertEquals(
            "2/3 人脸与声音",
            VoiceCloneStepTitlePolicy.title(
                VoiceCloneEnrollmentStep.VERIFYING,
                VoiceCloneSubmissionState.IDLE
            )
        )
        assertEquals(
            "3/3 声音克隆",
            VoiceCloneStepTitlePolicy.title(
                VoiceCloneEnrollmentStep.VERIFIED,
                VoiceCloneSubmissionState.PROCESSING
            )
        )
        assertEquals(
            "3/3 完成",
            VoiceCloneStepTitlePolicy.title(
                VoiceCloneEnrollmentStep.VERIFIED,
                VoiceCloneSubmissionState.READY
            )
        )
    }
}
