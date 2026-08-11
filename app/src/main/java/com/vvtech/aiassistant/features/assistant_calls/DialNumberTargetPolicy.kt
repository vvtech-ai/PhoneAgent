package com.vvtech.aiassistant.features.assistant_calls

internal fun normalizeDialTarget(value: String): String {
    val trimmed = value.trim()
    val body = trimmed.filter { it.isDigit() || it == '*' || it == '#' }
    if (body.isBlank()) return ""
    return if (trimmed.startsWith("+")) "+$body" else body
}
