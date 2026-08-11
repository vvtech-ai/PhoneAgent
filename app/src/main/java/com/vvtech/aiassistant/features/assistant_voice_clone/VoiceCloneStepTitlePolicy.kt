package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentStep

internal object VoiceCloneStepTitlePolicy {

    fun title(
        enrollmentStep: VoiceCloneEnrollmentStep,
        submissionState: VoiceCloneSubmissionState
    ): String = when {
        submissionState == VoiceCloneSubmissionState.READY -> "3/3 完成"
        enrollmentStep == VoiceCloneEnrollmentStep.CONSENT -> "身份认证"
        enrollmentStep == VoiceCloneEnrollmentStep.IDENTITY -> "1/3 填写信息"
        enrollmentStep == VoiceCloneEnrollmentStep.VERIFYING -> "2/3 人脸与声音"
        else -> "3/3 声音克隆"
    }
}
