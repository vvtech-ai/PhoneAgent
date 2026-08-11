package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

internal fun requireVoiceCloneVerificationScript(scriptText: String?): String =
    scriptText?.trim()?.takeIf(String::isNotEmpty)
        ?: throw IllegalStateException("声音克隆服务版本未同步，请稍后重试。")
