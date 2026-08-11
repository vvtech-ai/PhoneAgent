package com.vvtech.aiassistant.features.assistant_voice_clone

internal fun shouldShowVoiceCloneGuideForCallProvider(provider: String?): Boolean {
    val normalized = provider?.trim().orEmpty()
    return normalized.equals(QWEN_OMNI_PLUS, ignoreCase = true) ||
        normalized.equals(QWEN_OMNI_FLASH, ignoreCase = true)
}

private const val QWEN_OMNI_PLUS = "QWEN_OMNI_PLUS"
private const val QWEN_OMNI_FLASH = "QWEN_OMNI_FLASH"
