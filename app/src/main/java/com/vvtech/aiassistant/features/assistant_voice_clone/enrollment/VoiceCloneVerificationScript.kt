package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun requireVoiceCloneVerificationScript(scriptText: String?): String =
    scriptText?.trim()?.takeIf(String::isNotEmpty)
        ?: throw IllegalStateException(currentAppText(
            "声音克隆服务版本未同步，请稍后重试。",
            "Voice cloning service version is not synced. Please try again later."
        ))
