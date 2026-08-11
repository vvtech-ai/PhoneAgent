package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

internal object VoiceCloneSdkFailureMessagePolicy {
    fun messageFor(diagnosis: VoiceCloneSdkDiagnosis): String = when (diagnosis.code) {
        1001 -> systemErrorMessage(diagnosis.reasonCategory)
        1003 -> "认证已取消或中断，请重新开始。"
        2002 -> networkErrorMessage(diagnosis.reasonCategory)
        2003 -> "设备时间异常，请开启系统自动时间后重新开始。"
        else -> "认证未完成，请重新开始。"
    }

    private fun systemErrorMessage(category: VoiceCloneSdkReasonCategory): String = when (category) {
        VoiceCloneSdkReasonCategory.CAMERA_PERMISSION,
        VoiceCloneSdkReasonCategory.MICROPHONE_PERMISSION ->
            "认证组件缺少摄像头或麦克风权限，请检查权限后重新开始。"

        VoiceCloneSdkReasonCategory.CAMERA_OPEN,
        VoiceCloneSdkReasonCategory.MICROPHONE_OPEN ->
            "认证组件无法使用摄像头或麦克风，请关闭占用它们的应用后重新开始。"

        VoiceCloneSdkReasonCategory.DUPLICATE_FLOW ->
            "上一次认证尚未完全结束，请稍后重新开始。"

        VoiceCloneSdkReasonCategory.CERTIFY_ID_INVALID ->
            "认证信息已失效，请重新开始。"

        VoiceCloneSdkReasonCategory.DEVICE_UNSUPPORTED ->
            "当前设备暂不支持认证，请更换设备后重试。"

        else -> "认证组件运行异常，请重新开始；若连续出现，请检查摄像头和麦克风权限。"
    }

    private fun networkErrorMessage(category: VoiceCloneSdkReasonCategory): String =
        if (category == VoiceCloneSdkReasonCategory.PROVIDER_BUSY) {
            "认证服务暂时繁忙，请稍后重新开始。"
        } else {
            "网络连接异常，请检查网络后重新开始；若网络正常，请确认系统时间为自动设置。"
        }
}
