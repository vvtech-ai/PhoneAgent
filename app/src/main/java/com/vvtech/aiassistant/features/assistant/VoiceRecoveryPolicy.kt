package com.vvtech.aiassistant.features.assistant

internal data class VoiceRecoveryDecision(
    val retryable: Boolean,
    val status: String
)

private val NonRetryableVoiceFailurePatterns = listOf(
    Regex("""真实\s*SIP\s*未启用""", RegexOption.IGNORE_CASE),
    Regex("""\b(?:400|401|403|404)\b"""),
    Regex("""permission\s+denied|unauthorized|forbidden""", RegexOption.IGNORE_CASE),
    Regex("""参数错误|缺少必填|权限不足|未授权""")
)

private val RetryableVoiceFailurePatterns = listOf(
    Regex("""task[_\s-]?failed|sse|stream|eventsource""", RegexOption.IGNORE_CASE),
    Regex("""timeout|timed?\s*out|connect|socket|network|closed|eof""", RegexOption.IGNORE_CASE),
    Regex("""\b(?:429|500|502|503|504)\b"""),
    Regex("""too\s+many\s+requests|rate\s+limit|service\s+unavailable""", RegexOption.IGNORE_CASE),
    Regex("""转写|识别|语音|会话中断|连接异常""")
)

internal fun voiceRecoveryDecision(
    raw: String?,
    language: VoiceLanguage,
    fallbackStatus: String = localizedVoiceRecoveryResumeStatus(language)
): VoiceRecoveryDecision {
    val text = raw?.trim().orEmpty()
    if (text.isBlank()) {
        return VoiceRecoveryDecision(retryable = true, status = fallbackStatus)
    }
    if (Regex("""真实\s*SIP\s*未启用""", RegexOption.IGNORE_CASE).containsMatchIn(text)) {
        return VoiceRecoveryDecision(retryable = false, status = "真实 SIP 未启用")
    }
    if (NonRetryableVoiceFailurePatterns.any { it.containsMatchIn(text) }) {
        return VoiceRecoveryDecision(retryable = false, status = fallbackStatus)
    }
    val retryable = containsSensitiveNetworkError(text) ||
        RetryableVoiceFailurePatterns.any { it.containsMatchIn(text) }
    return VoiceRecoveryDecision(retryable = retryable, status = fallbackStatus)
}

internal fun localizedVoiceRecoveryRetryStatus(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "The connection was interrupted. Retrying..."
    VoiceLanguage.Japanese -> "接続が中断されました。再試行しています..."
    VoiceLanguage.Chinese -> "连接中断，正在自动重试..."
}

internal fun localizedVoiceRecoveryResumeStatus(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Voice is ready. Please continue."
    VoiceLanguage.Japanese -> "音声入力を続けられます。"
    VoiceLanguage.Chinese -> "语音已恢复，可以继续说"
}

internal fun localizedVoiceRecoveryFallbackStatus(language: VoiceLanguage): String = when (language) {
    VoiceLanguage.English -> "Switching recognition mode..."
    VoiceLanguage.Japanese -> "別の認識方式に切り替えています..."
    VoiceLanguage.Chinese -> "正在切换识别方式..."
}
