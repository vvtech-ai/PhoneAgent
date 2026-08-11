package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.domain.task.isNetworkTaskExecutionStatus

private val SensitiveNetworkErrorPatterns = listOf(
    Regex("""\b(?:\d{1,3}\.){3}\d{1,3}\b"""),
    Regex("""\bport\s+\d+\b""", RegexOption.IGNORE_CASE),
    Regex("""\b(?:408|425|429|500|502|503|504)\b"""),
    Regex("""http\s*(?:408|425|429|500|502|503|504)""", RegexOption.IGNORE_CASE),
    Regex("""service\s+unavailable|gateway\s+timeout|too\s+many\s+requests""", RegexOption.IGNORE_CASE),
    Regex("""after\s+\d+\s*ms\b""", RegexOption.IGNORE_CASE),
    Regex("""failed\s+to\s+connect""", RegexOption.IGNORE_CASE),
    Regex("""(?:first_audio_timeout|completion_timeout|voice\s+tts\s+failed|tts.*timeout|asr.*timeout|_timeout\b|\btimeout\b)""", RegexOption.IGNORE_CASE),
    Regex("""(?:connect|read|write)\s+timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""unable\s+to\s+resolve\s+host""", RegexOption.IGNORE_CASE),
    Regex("""unknownhost|sockettimeout|connectexception""", RegexOption.IGNORE_CASE),
    Regex("""connection\s+refused|connection\s+reset|broken\s+pipe""", RegexOption.IGNORE_CASE),
    Regex("""no\s+route\s+to\s+host|network\s+is\s+unreachable""", RegexOption.IGNORE_CASE),
    Regex("""econnrefused|econnreset|enetunreach|ehostunreach|socketexception""", RegexOption.IGNORE_CASE),
    Regex("""sslhandshake|clearttext|cleartext""", RegexOption.IGNORE_CASE),
    Regex("""网络异常|网络连接异常|网络错误|连接异常|连接中断|服务暂时不可用|服务响应超时|请求超时|超时""")
)

/**
 * Failures that indicate the device-to-service transport was actually interrupted.
 *
 * This is intentionally narrower than [SensitiveNetworkErrorPatterns]. HTTP 429/5xx,
 * provider unavailability and model timeouts still need display sanitization, but they
 * are service/model failures rather than proof that the device network is disconnected.
 */
private val TransportNetworkErrorPatterns = listOf(
    Regex("""\bhttp\s*408\b""", RegexOption.IGNORE_CASE),
    Regex("""failed\s+to\s+connect""", RegexOption.IGNORE_CASE),
    Regex("""(?:first_audio_timeout|completion_timeout|voice\s+tts\s+failed|tts.*timeout|asr.*timeout)""", RegexOption.IGNORE_CASE),
    Regex("""(?:connect|read|write)\s+timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""connection\s+timed?\s*out""", RegexOption.IGNORE_CASE),
    Regex("""network\s+(?:connection\s+)?(?:error|timeout|failure|unavailable)""", RegexOption.IGNORE_CASE),
    Regex("""unable\s+to\s+resolve\s+host""", RegexOption.IGNORE_CASE),
    Regex("""unknownhost|sockettimeout|connectexception""", RegexOption.IGNORE_CASE),
    Regex("""connection\s+refused|connection\s+reset|connection\s+closed|broken\s+pipe""", RegexOption.IGNORE_CASE),
    Regex("""no\s+route\s+to\s+host|network\s+is\s+unreachable""", RegexOption.IGNORE_CASE),
    Regex("""econnrefused|econnreset|enetunreach|ehostunreach|socketexception""", RegexOption.IGNORE_CASE),
    Regex("""sslhandshake|clearttext|cleartext""", RegexOption.IGNORE_CASE),
    Regex("""网络异常|网络连接异常|网络错误|连接异常|连接中断|无法连接|连接失败|域名解析失败|主机无法解析""")
)

internal fun userFacingNetworkErrorMessage(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Network connection error. Please check your network and try again."
    VoiceLanguage.Japanese -> "ネットワーク接続エラーです。ネットワークを確認してから再試行してください。"
    VoiceLanguage.Chinese -> "网络连接异常，请检查网络后重试"
}

internal fun containsSensitiveNetworkError(raw: String?): Boolean {
    val text = raw.orEmpty()
    if (text.isBlank()) return false
    return SensitiveNetworkErrorPatterns.any { it.containsMatchIn(text) }
}

internal fun containsTransportNetworkError(raw: String?): Boolean {
    val text = raw.orEmpty()
    if (text.isBlank()) return false
    return TransportNetworkErrorPatterns.any { it.containsMatchIn(text) }
}

internal fun isNetworkTaskStatus(status: String?): Boolean {
    val normalized = status?.trim().orEmpty()
    if (normalized.isBlank()) return false
    return isNetworkTaskExecutionStatus(normalized) || normalized.contains("网络异常")
}

internal fun networkTaskErrorStatusMessage(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Network error. The task is paused. Check your connection and continue."
    VoiceLanguage.Japanese -> "ネットワーク異常です。タスクを一時停止しました。接続を確認してから続けてください。"
    VoiceLanguage.Chinese -> "网络异常，任务已暂停，请检查网络后继续"
}

internal fun sanitizeUserFacingError(
    raw: String?,
    language: VoiceLanguage = VoiceLanguage.Chinese,
    fallback: String = userFacingNetworkErrorMessage(language)
): String {
    val text = raw?.trim().orEmpty()
    if (text.isBlank()) return fallback
    return if (containsSensitiveNetworkError(text)) {
        userFacingNetworkErrorMessage(language)
    } else {
        text
    }
}

internal fun sanitizeUserFacingNetworkText(
    raw: String?,
    language: VoiceLanguage = VoiceLanguage.Chinese
): String {
    val text = raw.orEmpty()
    if (text.isBlank()) return ""
    return if (containsSensitiveNetworkError(text)) {
        userFacingNetworkErrorMessage(language)
    } else {
        text
    }
}
