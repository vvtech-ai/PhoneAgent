package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

internal object VoiceCloneSdkResultPolicy {
    private val serverQueryCodes = setOf(1000, 2006)

    fun requiresServerQuery(code: Int): Boolean = code in serverQueryCodes
}
