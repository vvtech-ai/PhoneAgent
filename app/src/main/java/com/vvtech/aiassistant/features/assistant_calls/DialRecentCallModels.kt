package com.vvtech.aiassistant.features.assistant_calls

internal enum class DialRecentCallSource {
    SYSTEM,
    SIP,
    LOCAL_AGENT
}

internal enum class DialRecentCallKind {
    AGENT,
    NORMAL,
    TRANSLATION
}

internal enum class DialRecentCallDirection {
    INCOMING,
    OUTGOING,
    MISSED,
    UNKNOWN
}

internal enum class DialRecentCallStatus {
    COMPLETED,
    FAILED,
    MISSED
}

internal data class DialRecentCall(
    val id: String,
    val phoneNumber: String,
    val displayName: String,
    val startedAtMillis: Long,
    val durationSeconds: Long,
    val direction: DialRecentCallDirection,
    val status: DialRecentCallStatus,
    val source: DialRecentCallSource,
    val kind: DialRecentCallKind,
    val failureReason: String = "",
    val countryIso: String = "",
    val callerLanguageCode: String = "",
    val calleeLanguageCode: String = ""
)

internal fun mergeDialRecentCalls(
    systemRecords: List<DialRecentCall>,
    localRecords: List<DialRecentCall>,
    limit: Int = 100
): List<DialRecentCall> = (systemRecords + localRecords)
    .asSequence()
    .filter {
        it.source == DialRecentCallSource.SYSTEM ||
            it.kind == DialRecentCallKind.TRANSLATION
    }
    .distinctBy { "${it.source}:${it.id}" }
    .sortedByDescending(DialRecentCall::startedAtMillis)
    .take(limit)
    .toList()
