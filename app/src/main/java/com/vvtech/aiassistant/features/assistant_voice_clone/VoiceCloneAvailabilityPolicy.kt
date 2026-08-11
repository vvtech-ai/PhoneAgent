package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.model.VoiceCloneStatusResponse

internal object VoiceCloneAvailabilityPolicy {
    fun canEnroll(status: VoiceCloneStatusResponse?): Boolean =
        status?.enrollmentAvailable == true

    fun enrollmentUnavailableMessage(status: VoiceCloneStatusResponse?): String =
        if (status == null) {
            "身份认证凭证恢复未成功，请点击身份认证重试"
        } else {
            "当前环境未配置实名认证或朗读校验，暂不可采集声音"
        }

    fun shouldShowEntry(status: VoiceCloneStatusResponse?, hasClone: Boolean): Boolean =
        hasClone || canEnroll(status)
}
