package com.vvtech.aiassistant.logging

import java.util.Locale

enum class RuntimeStateLogDomain(val tag: String) {
    APP("APP_STATE"),
    TASK("TASK_STATE"),
    VOICE("VOICE_STATE"),
    TTS("TTS_STATE"),
    ASR("ASR_STATE"),
    AGENT("AGENT_STATE"),
    CALL("CALL_STATE"),
    SIP("SIP_STATE"),
    TRANSLATION("TRANSLATION_STATE"),
    CONTACT("CONTACT_STATE"),
    OTA("OTA_STATE"),
    NETWORK("NETWORK_STATE"),
    SETTINGS("SETTINGS_STATE"),
    LOG_EXPORT("LOG_EXPORT_STATE")
}

enum class RuntimeStateLogLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR
}

data class RuntimeStateLogEvent(
    val domain: RuntimeStateLogDomain,
    val eventType: String,
    val traceId: String? = null,
    val commandId: String? = null,
    val sessionId: String? = null,
    val taskId: String? = null,
    val callAttemptId: String? = null,
    val callId: String? = null,
    val eventId: String? = null,
    val sequence: Long? = null,
    val provider: String? = null,
    val trigger: String? = null,
    val stateBefore: String? = null,
    val stateAfter: String? = null,
    val result: String? = null,
    val reason: String? = null,
    val elapsedMs: Long? = null,
    val message: String? = null,
    val attributes: Map<String, String?> = emptyMap()
)

object RuntimeStateLogger {
    fun debug(event: RuntimeStateLogEvent, throwable: Throwable? = null) {
        log(RuntimeStateLogLevel.DEBUG, event, throwable)
    }

    fun info(event: RuntimeStateLogEvent, throwable: Throwable? = null) {
        log(RuntimeStateLogLevel.INFO, event, throwable)
    }

    fun warn(event: RuntimeStateLogEvent, throwable: Throwable? = null) {
        log(RuntimeStateLogLevel.WARN, event, throwable)
    }

    fun error(event: RuntimeStateLogEvent, throwable: Throwable? = null) {
        log(RuntimeStateLogLevel.ERROR, event, throwable)
    }

    fun log(
        level: RuntimeStateLogLevel,
        event: RuntimeStateLogEvent,
        throwable: Throwable? = null
    ) {
        val message = event.formatForLog()
        when (level) {
            RuntimeStateLogLevel.DEBUG -> AppFileLogger.d(event.domain.tag, message, throwable)
            RuntimeStateLogLevel.INFO -> AppFileLogger.i(event.domain.tag, message, throwable)
            RuntimeStateLogLevel.WARN -> AppFileLogger.w(event.domain.tag, message, throwable)
            RuntimeStateLogLevel.ERROR -> AppFileLogger.e(event.domain.tag, message, throwable)
        }
    }
}

internal fun RuntimeStateLogEvent.formatForLog(): String {
    val pairs = mutableListOf<String>()
    pairs.addPair("eventType", eventType.ifBlank { "unknown_event" })
    pairs.addPair("traceId", traceId)
    pairs.addPair("commandId", commandId)
    pairs.addPair("sessionId", sessionId)
    pairs.addPair("taskId", taskId)
    pairs.addPair("callAttemptId", callAttemptId)
    pairs.addPair("callId", callId)
    pairs.addPair("eventId", eventId)
    pairs.addPair("sequence", sequence?.toString())
    pairs.addPair("provider", provider)
    pairs.addPair("trigger", trigger)
    pairs.addPair("stateBefore", stateBefore)
    pairs.addPair("stateAfter", stateAfter)
    pairs.addPair("result", result)
    pairs.addPair("reason", reason)
    pairs.addPair("elapsedMs", elapsedMs?.toString())
    attributes.entries
        .sortedBy { it.key }
        .forEach { entry ->
            pairs.addPair("attr.${entry.key.toLogKey()}", entry.value, sourceKey = entry.key)
        }
    pairs.addPair("message", message)
    return pairs.joinToString(separator = " ")
}

private fun MutableList<String>.addPair(
    key: String,
    value: String?,
    sourceKey: String = key
) {
    val formatted = value.toRuntimeLogValue(sourceKey) ?: return
    add("${key.toLogKey()}=$formatted")
}

private fun String?.toRuntimeLogValue(sourceKey: String): String? {
    val raw = this?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    if (raw.equals("null", ignoreCase = true)) return null
    if (sourceKey.isSensitiveLogKey()) return RedactedValue
    return raw
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace(WhitespaceRegex, "_")
        .maskPhoneLikeValues()
        .limitRuntimeLogValue()
        .takeIf { it.isNotBlank() }
}

private fun String.limitRuntimeLogValue(): String {
    if (length <= MaxValueLength) return this
    return take(MaxValueLength) + "...[truncated:$length]"
}

private fun String.maskPhoneLikeValues(): String {
    return replace(ChinaMobileRegex) { match ->
        match.value.maskDigits(visibleTail = 4)
    }.replace(LongDigitRegex) { match ->
        match.value.maskDigits(visibleTail = 4)
    }
}

private fun String.maskDigits(visibleTail: Int): String {
    val digits = filter { it.isDigit() }
    val tail = digits.takeLast(visibleTail)
    return "[digits:${digits.length}:****$tail]"
}

private fun String.isSensitiveLogKey(): Boolean {
    val normalized = lowercase(Locale.ROOT).replace(NonKeyCharRegex, "")
    return SensitiveKeyParts.any { normalized.contains(it) }
}

private fun String.toLogKey(): String {
    return trim()
        .replace(NonKeyCharRegex, "_")
        .trim('_')
        .ifBlank { "unknown" }
}

private const val MaxValueLength = 160
private const val RedactedValue = "[redacted]"

private val WhitespaceRegex = Regex("\\s+")
private val NonKeyCharRegex = Regex("[^A-Za-z0-9_.-]+")
private val ChinaMobileRegex = Regex("(?<!\\d)(?:\\+?86[-_ ]?)?1[3-9]\\d{9}(?!\\d)")
private val LongDigitRegex = Regex("(?<!\\d)\\d{15,}(?!\\d)")
private val SensitiveKeyParts = listOf(
    "phone",
    "mobile",
    "telephone",
    "token",
    "secret",
    "password",
    "authorization",
    "credential",
    "apikey",
    "accesskey",
    "account",
    "accountid",
    "contact",
    "prompt",
    "transcript",
    "payload",
    "audio"
)
