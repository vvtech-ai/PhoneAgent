package com.vvtech.aiassistant.features.assistant_ui

internal object AssistantCallModelDisplayNames {
    const val Qwen = "QwenOmniPlus"
    const val Doubao = "Seeduplex"

    fun resolve(provider: String?, displayName: String?): String? {
        val raw = provider?.trim().orEmpty()
        if (
            raw.contains("QWEN", ignoreCase = true) ||
            raw.contains("ALIBABA", ignoreCase = true) ||
            raw.contains("千问") ||
            raw.contains("阿里")
        ) {
            return Qwen
        }
        val serverDisplayName = displayName?.trim()?.ifBlank { null }
        if (serverDisplayName != null) {
            return serverDisplayName
        }
        return when {
            raw.isBlank() -> null
            raw.contains("DOUBAO", ignoreCase = true) ||
                raw.contains("VOLCANO", ignoreCase = true) ||
                raw.contains("豆包") -> Doubao
            else -> null
        }
    }

    fun resolveOrDefault(raw: String): String = resolve(raw, raw) ?: Qwen
}
