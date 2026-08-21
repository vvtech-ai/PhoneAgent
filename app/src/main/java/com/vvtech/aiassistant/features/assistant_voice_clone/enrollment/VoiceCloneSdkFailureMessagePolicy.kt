package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal object VoiceCloneSdkFailureMessagePolicy {
    fun messageFor(diagnosis: VoiceCloneSdkDiagnosis): String = when (diagnosis.code) {
        1001 -> systemErrorMessage(diagnosis.reasonCategory)
        1003 -> currentAppText(
            "认证已取消或中断，请重新开始。",
            "Verification was canceled or interrupted. Please start again."
        )
        2002 -> networkErrorMessage(diagnosis.reasonCategory)
        2003 -> currentAppText(
            "设备时间异常，请开启系统自动时间后重新开始。",
            "Device time is incorrect. Turn on automatic system time, then start again."
        )
        else -> currentAppText(
            "认证未完成，请重新开始。",
            "Verification was not completed. Please start again."
        )
    }

    private fun systemErrorMessage(category: VoiceCloneSdkReasonCategory): String = when (category) {
        VoiceCloneSdkReasonCategory.CAMERA_PERMISSION,
        VoiceCloneSdkReasonCategory.MICROPHONE_PERMISSION ->
            currentAppText(
                "认证组件缺少摄像头或麦克风权限，请检查权限后重新开始。",
                "The verification component is missing camera or microphone permission. Check permissions and start again."
            )

        VoiceCloneSdkReasonCategory.CAMERA_OPEN,
        VoiceCloneSdkReasonCategory.MICROPHONE_OPEN ->
            currentAppText(
                "认证组件无法使用摄像头或麦克风，请关闭占用它们的应用后重新开始。",
                "The verification component cannot use the camera or microphone. Close apps using them, then start again."
            )

        VoiceCloneSdkReasonCategory.DUPLICATE_FLOW ->
            currentAppText(
                "上一次认证尚未完全结束，请稍后重新开始。",
                "The previous verification has not fully ended. Please try again later."
            )

        VoiceCloneSdkReasonCategory.CERTIFY_ID_INVALID ->
            currentAppText(
                "认证信息已失效，请重新开始。",
                "Verification information has expired. Please start again."
            )

        VoiceCloneSdkReasonCategory.DEVICE_UNSUPPORTED ->
            currentAppText(
                "当前设备暂不支持认证，请更换设备后重试。",
                "This device does not support verification. Try again on another device."
            )

        else -> currentAppText(
            "认证组件运行异常，请重新开始；若连续出现，请检查摄像头和麦克风权限。",
            "The verification component ran into an error. Start again; if it keeps happening, check camera and microphone permissions."
        )
    }

    private fun networkErrorMessage(category: VoiceCloneSdkReasonCategory): String =
        if (category == VoiceCloneSdkReasonCategory.PROVIDER_BUSY) {
            currentAppText(
                "认证服务暂时繁忙，请稍后重新开始。",
                "Verification service is busy. Please try again later."
            )
        } else {
            currentAppText(
                "网络连接异常，请检查网络后重新开始；若网络正常，请确认系统时间为自动设置。",
                "Network connection failed. Check the network and start again; if the network is fine, make sure system time is automatic."
            )
        }
}
