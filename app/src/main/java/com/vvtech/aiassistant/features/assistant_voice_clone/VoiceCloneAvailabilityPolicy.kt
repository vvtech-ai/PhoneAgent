package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse

internal object VoiceCloneAvailabilityPolicy {
    fun canEnroll(status: VoiceCloneStatusResponse?): Boolean =
        status?.enrollmentAvailable == true

    fun enrollmentUnavailableMessage(status: VoiceCloneStatusResponse?): String =
        if (status == null) {
            currentAppText(
                "身份认证凭证恢复未成功，请点击身份认证重试",
                "Identity verification credentials could not be restored. Tap identity verification to try again"
            )
        } else {
            currentAppText(
                "当前环境未配置实名认证或朗读校验，暂不可采集声音",
                "Real-name verification or reading validation is not configured, so voice enrollment is unavailable"
            )
        }

    fun shouldShowEntry(status: VoiceCloneStatusResponse?, hasClone: Boolean): Boolean =
        hasClone || canEnroll(status)
}
