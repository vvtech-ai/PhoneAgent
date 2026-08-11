package com.vvtech.aiassistant.features.assistant_voice_clone

import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import java.security.MessageDigest

internal fun logVoiceCloneRuntime(
    eventType: String,
    result: String? = null,
    reason: String? = null,
    statusValue: String? = null,
    throwable: Throwable? = null,
    attributes: Map<String, String?> = emptyMap(),
    attemptId: String? = null,
    collectionId: String? = null,
    provider: String? = null,
    stateBefore: String? = null,
    stateAfter: String? = null,
    elapsedMs: Long? = null
) {
    val event = voiceCloneRuntimeEvent(
        eventType = eventType,
        result = result,
        reason = reason,
        statusValue = statusValue,
        throwable = throwable,
        attributes = attributes,
        attemptId = attemptId,
        collectionId = collectionId,
        provider = provider,
        stateBefore = stateBefore,
        stateAfter = stateAfter,
        elapsedMs = elapsedMs
    )
    if (throwable == null) {
        RuntimeStateLogger.info(event)
    } else {
        RuntimeStateLogger.warn(event, throwable.toSafeLogThrowable())
    }
}

internal fun voiceCloneRuntimeEvent(
    eventType: String,
    result: String? = null,
    reason: String? = null,
    statusValue: String? = null,
    throwable: Throwable? = null,
    attributes: Map<String, String?> = emptyMap(),
    attemptId: String? = null,
    collectionId: String? = null,
    provider: String? = null,
    stateBefore: String? = null,
    stateAfter: String? = null,
    elapsedMs: Long? = null
): RuntimeStateLogEvent {
    val safeAttributes = attributes + mapOf(
        "voiceCloneStatus" to statusValue,
        "collectionRef" to voiceCloneLogRef(collectionId),
        "errorType" to throwable?.javaClass?.simpleName
    )
    return RuntimeStateLogEvent(
        domain = RuntimeStateLogDomain.SETTINGS,
        eventType = eventType,
        traceId = voiceCloneLogRef(attemptId),
        provider = provider,
        stateBefore = stateBefore,
        stateAfter = stateAfter,
        result = result,
        reason = reason,
        elapsedMs = elapsedMs,
        attributes = safeAttributes
    )
}

internal fun voiceCloneLogRef(value: String?): String? {
    val normalized = value?.trim()?.takeIf(String::isNotEmpty) ?: return null
    return MessageDigest.getInstance("SHA-256")
        .digest(normalized.toByteArray(Charsets.UTF_8))
        .joinToString(separator = "") { byte -> "%02x".format(byte) }
        .take(LOG_REF_LENGTH)
}

private fun Throwable.toSafeLogThrowable(): Throwable =
    RuntimeException(javaClass.simpleName).also { safe -> safe.stackTrace = stackTrace }

private const val LOG_REF_LENGTH = 12
