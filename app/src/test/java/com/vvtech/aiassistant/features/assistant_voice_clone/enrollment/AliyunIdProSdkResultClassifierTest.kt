package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Test

class AliyunIdProSdkResultClassifierTest {
    @Test
    fun `known sdk subcodes are classified without retaining raw reason`() {
        val diagnosis = AliyunIdProSdkResultClassifier.classify(
            IdProSdkResult(1001, "camera failed, subCode=Z1019, user text must not leak")
        )

        assertEquals(1001, diagnosis.code)
        assertEquals("Z1019", diagnosis.subCode)
        assertEquals(VoiceCloneSdkReasonCategory.CAMERA_PERMISSION, diagnosis.reasonCategory)
        assertFalse(diagnosis.toString().contains("user text must not leak"))
    }

    @Test
    fun `audio upload network error keeps only safe subcode`() {
        val diagnosis = AliyunIdProSdkResultClassifier.classify(
            IdProSdkResult(2002, "upload error [Z5116]")
        )

        assertEquals("Z5116", diagnosis.subCode)
        assertEquals(VoiceCloneSdkReasonCategory.NETWORK_UPLOAD, diagnosis.reasonCategory)
    }

    @Test
    fun `unstructured reason becomes safe generic category`() {
        val diagnosis = AliyunIdProSdkResultClassifier.classify(
            IdProSdkResult(1001, "包含姓名手机号或任意供应商文本")
        )

        assertNull(diagnosis.subCode)
        assertEquals(VoiceCloneSdkReasonCategory.SDK_INTERNAL, diagnosis.reasonCategory)
    }

    @Test
    fun `network and permission categories produce actionable messages`() {
        assertEquals(
            "网络连接异常，请检查网络后重新开始；若网络正常，请确认系统时间为自动设置。",
            VoiceCloneSdkFailureMessagePolicy.messageFor(
                VoiceCloneSdkDiagnosis(2002, "Z1012", VoiceCloneSdkReasonCategory.NETWORK_ACCESS)
            )
        )
        assertEquals(
            "认证组件缺少摄像头或麦克风权限，请检查权限后重新开始。",
            VoiceCloneSdkFailureMessagePolicy.messageFor(
                VoiceCloneSdkDiagnosis(1001, "Z1030", VoiceCloneSdkReasonCategory.MICROPHONE_PERMISSION)
            )
        )
    }
}
