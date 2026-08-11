package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

internal enum class VoiceCloneSdkReasonCategory {
    SUCCESS,
    VERIFICATION_REJECTED,
    USER_CANCELLED,
    CAMERA_PERMISSION,
    CAMERA_OPEN,
    MICROPHONE_PERMISSION,
    MICROPHONE_OPEN,
    SDK_INITIALIZATION,
    DUPLICATE_FLOW,
    CERTIFY_ID_INVALID,
    DEVICE_UNSUPPORTED,
    NETWORK_INITIALIZATION,
    NETWORK_ACCESS,
    NETWORK_UPLOAD,
    PROVIDER_BUSY,
    DEVICE_TIME,
    SDK_INTERNAL,
    UNKNOWN
}

internal data class VoiceCloneSdkDiagnosis(
    val code: Int,
    val subCode: String?,
    val reasonCategory: VoiceCloneSdkReasonCategory
)

internal object AliyunIdProSdkResultClassifier {
    private val subCodePattern = Regex("(?<![A-Z0-9_])([ZA]\\d{4}(?:_\\d+)?)(?![A-Z0-9_])")

    fun classify(result: IdProSdkResult): VoiceCloneSdkDiagnosis {
        val subCode = subCodePattern.find(result.reason.uppercase())?.groupValues?.get(1)
        return VoiceCloneSdkDiagnosis(
            code = result.code,
            subCode = subCode,
            reasonCategory = reasonCategory(result.code, subCode)
        )
    }

    private fun reasonCategory(code: Int, subCode: String?): VoiceCloneSdkReasonCategory {
        knownSubCodeCategories[subCode]?.let { return it }
        return when (code) {
            1000 -> VoiceCloneSdkReasonCategory.SUCCESS
            1003 -> VoiceCloneSdkReasonCategory.USER_CANCELLED
            2002 -> VoiceCloneSdkReasonCategory.NETWORK_ACCESS
            2003 -> VoiceCloneSdkReasonCategory.DEVICE_TIME
            2006 -> VoiceCloneSdkReasonCategory.VERIFICATION_REJECTED
            1001 -> VoiceCloneSdkReasonCategory.SDK_INTERNAL
            else -> VoiceCloneSdkReasonCategory.UNKNOWN
        }
    }

    private val knownSubCodeCategories = mapOf(
        "Z1019" to VoiceCloneSdkReasonCategory.CAMERA_PERMISSION,
        "Z1030" to VoiceCloneSdkReasonCategory.MICROPHONE_PERMISSION,
        "Z1002" to VoiceCloneSdkReasonCategory.CAMERA_OPEN,
        "Z1020" to VoiceCloneSdkReasonCategory.CAMERA_OPEN,
        "Z1021" to VoiceCloneSdkReasonCategory.CAMERA_OPEN,
        "Z1032" to VoiceCloneSdkReasonCategory.MICROPHONE_OPEN,
        "Z1001" to VoiceCloneSdkReasonCategory.SDK_INITIALIZATION,
        "Z1035" to VoiceCloneSdkReasonCategory.SDK_INITIALIZATION,
        "Z1036" to VoiceCloneSdkReasonCategory.SDK_INITIALIZATION,
        "Z1024" to VoiceCloneSdkReasonCategory.DUPLICATE_FLOW,
        "Z1037" to VoiceCloneSdkReasonCategory.CERTIFY_ID_INVALID,
        "Z1003" to VoiceCloneSdkReasonCategory.DEVICE_UNSUPPORTED,
        "Z1004" to VoiceCloneSdkReasonCategory.DEVICE_UNSUPPORTED,
        "Z1018" to VoiceCloneSdkReasonCategory.DEVICE_UNSUPPORTED,
        "Z1029" to VoiceCloneSdkReasonCategory.DEVICE_UNSUPPORTED,
        "Z1011" to VoiceCloneSdkReasonCategory.NETWORK_INITIALIZATION,
        "Z1025" to VoiceCloneSdkReasonCategory.NETWORK_INITIALIZATION,
        "Z1012" to VoiceCloneSdkReasonCategory.NETWORK_ACCESS,
        "Z1027" to VoiceCloneSdkReasonCategory.NETWORK_ACCESS,
        "Z1040" to VoiceCloneSdkReasonCategory.NETWORK_ACCESS,
        "Z1026" to VoiceCloneSdkReasonCategory.NETWORK_UPLOAD,
        "Z5112" to VoiceCloneSdkReasonCategory.NETWORK_UPLOAD,
        "Z5113" to VoiceCloneSdkReasonCategory.NETWORK_UPLOAD,
        "Z5114" to VoiceCloneSdkReasonCategory.NETWORK_UPLOAD,
        "Z5116" to VoiceCloneSdkReasonCategory.NETWORK_UPLOAD,
        "Z6002" to VoiceCloneSdkReasonCategory.NETWORK_UPLOAD,
        "Z1028" to VoiceCloneSdkReasonCategory.PROVIDER_BUSY,
        "Z1000" to VoiceCloneSdkReasonCategory.SDK_INTERNAL,
        "Z1023" to VoiceCloneSdkReasonCategory.SDK_INTERNAL,
        "Z7001" to VoiceCloneSdkReasonCategory.SDK_INTERNAL,
        "A4001" to VoiceCloneSdkReasonCategory.SDK_INTERNAL,
        "A4005" to VoiceCloneSdkReasonCategory.SDK_INTERNAL
    )
}
