package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.TranscriptLine

internal fun taskCallHistoryAttemptKey(taskId: String, attempt: Int): String {
    return "task=${taskId.trim()}|attempt=$attempt"
}

internal const val LegacyTaskCallHistoryAttemptId = "legacy"
internal const val PendingTaskCallHistoryAttemptId = "pending"

internal fun taskCallHistoryLegacyAttemptKey(taskId: String): String {
    return "task=${taskId.trim()}|attempt=$LegacyTaskCallHistoryAttemptId"
}

internal fun taskCallHistoryPendingAttemptKey(taskId: String): String {
    return "task=${taskId.trim()}|attempt=$PendingTaskCallHistoryAttemptId"
}

internal fun taskCallHistoryAttemptIdFromKey(key: String, callId: String?): String {
    val safeCallId = callId?.trim().orEmpty()
    if (safeCallId.isNotBlank()) return safeCallId
    return key.substringAfter("|attempt=", "").ifBlank {
        key.substringAfter("|local=", "").ifBlank { PendingTaskCallHistoryAttemptId }
    }
}

internal fun taskCallHistoryStoredKey(
    storedKey: String,
    taskId: String,
    callId: String?
): String {
    return if (storedKey == taskId.trim() && callId.isNullOrBlank()) {
        taskCallHistoryLegacyAttemptKey(taskId)
    } else {
        storedKey
    }
}

internal fun taskCallHistoryFallbackCallKey(taskId: String, fingerprint: String): String {
    return "task=${taskId.trim()}|local=$fingerprint"
}

internal fun taskCallHistoryTerminalFingerprint(
    phoneNumber: String,
    resultText: String,
    transcript: List<TranscriptLine>
): String {
    val source = buildString {
        append(phoneNumber.trim())
        append('\n')
        append(resultText.trim())
        transcript.forEach { line ->
            append('\n')
            append(line.role.name)
            append(':')
            append(line.text.trim())
        }
    }
    return Integer.toHexString(source.hashCode())
}

internal fun TaskCallHistoryEntry.sameTerminalPayload(
    phoneNumber: String,
    resultText: String,
    transcript: List<TranscriptLine>
): Boolean {
    if (!finalState) {
        return false
    }
    val samePhone = this.phoneNumber == phoneNumber.trim()
    val sameTranscript = transcript.isNotEmpty() && this.transcript == transcript
    val sameResultWithoutTranscript = transcript.isEmpty() &&
        this.transcript.isEmpty() &&
        resultText.trim().isNotBlank() &&
        this.resultText == resultText.trim()
    return samePhone && (sameTranscript || sameResultWithoutTranscript)
}
