package com.vvtech.aiassistant.features.assistant

import java.util.Locale

internal fun isBackendTaskVoiceProvider(provider: String): Boolean {
    val normalized = provider.trim().lowercase(Locale.US)
    return normalized == "qwen" || normalized == "doubao"
}
