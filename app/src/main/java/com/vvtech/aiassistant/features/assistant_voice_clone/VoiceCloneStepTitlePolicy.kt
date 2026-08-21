package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentStep

internal object VoiceCloneStepTitlePolicy {

    fun title(
        enrollmentStep: VoiceCloneEnrollmentStep,
        submissionState: VoiceCloneSubmissionState
    ): String = when {
        submissionState == VoiceCloneSubmissionState.READY -> currentAppText("3/3 完成", "3/3 Complete")
        enrollmentStep == VoiceCloneEnrollmentStep.CONSENT -> currentAppText("身份认证", "Identity Verification")
        enrollmentStep == VoiceCloneEnrollmentStep.IDENTITY -> currentAppText("1/3 填写信息", "1/3 Verification Details")
        enrollmentStep == VoiceCloneEnrollmentStep.VERIFYING -> currentAppText("2/3 人脸与声音", "2/3 Face & Voice")
        else -> currentAppText("3/3 声音克隆", "3/3 Voice Cloning")
    }
}
