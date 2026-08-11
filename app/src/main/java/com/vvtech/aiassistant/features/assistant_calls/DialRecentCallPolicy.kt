package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.features.assistant.DialCallKind
import com.vvtech.aiassistant.features.assistant.FinalCallRecord

internal const val MaxDialRecentCalls = 20

internal enum class DialRecentCallClickAction {
    FILL_INPUT,
    UNAVAILABLE
}

internal fun dialHistoryTypeLabel(kind: DialRecentCallKind): String? =
    if (kind == DialRecentCallKind.TRANSLATION) "实时翻译" else null

internal fun dialRecentCallClickAction(record: DialRecentCall): DialRecentCallClickAction = when {
    record.phoneNumber.isBlank() ||
        record.phoneNumber == "-1" ||
        record.phoneNumber == "-2" -> DialRecentCallClickAction.UNAVAILABLE
    else -> DialRecentCallClickAction.FILL_INPUT
}

internal fun dialRecentCallRecords(
    records: List<FinalCallRecord>
): List<FinalCallRecord> = records
    .asSequence()
    .filter { it.callKind == DialCallKind.NORMAL || it.callKind == DialCallKind.TRANSLATION }
    .sortedByDescending { it.occurredAtMillis ?: Long.MIN_VALUE }
    .take(MaxDialRecentCalls)
    .toList()

internal fun translationDialRecentCallRecords(
    records: List<FinalCallRecord>
): List<FinalCallRecord> = records
    .asSequence()
    .filter { it.callKind == DialCallKind.TRANSLATION }
    .sortedByDescending { it.occurredAtMillis ?: Long.MIN_VALUE }
    .take(MaxDialRecentCalls)
    .toList()

internal fun localDialRecentCalls(
    records: List<FinalCallRecord>,
    contacts: List<DialContactEntry> = emptyList()
): List<DialRecentCall> =
    records.mapNotNull { record ->
        val kind = when (record.callKind) {
            DialCallKind.AGENT -> DialRecentCallKind.AGENT
            DialCallKind.NORMAL -> DialRecentCallKind.NORMAL
            DialCallKind.TRANSLATION -> DialRecentCallKind.TRANSLATION
        }
        if (kind == DialRecentCallKind.AGENT) return@mapNotNull null
        DialRecentCall(
            id = record.callId.ifBlank {
                "${record.phoneNumber}:${record.occurredAtMillis ?: 0L}:${record.callKind}"
            },
            phoneNumber = dialRecentRestorablePhoneNumber(
                phoneNumber = record.phoneNumber,
                countryIso = record.dialCountryIso
            ),
            displayName = dialContactDisplayName(record.phoneNumber, contacts)
                .ifBlank { dialRecentDisplayName(record.title, record.phoneNumber) },
            startedAtMillis = record.occurredAtMillis ?: 0L,
            durationSeconds = parseDialDurationSeconds(record.durationText),
            direction = DialRecentCallDirection.OUTGOING,
            status = if (record.success) {
                DialRecentCallStatus.COMPLETED
            } else {
                DialRecentCallStatus.FAILED
            },
            source = DialRecentCallSource.SIP,
            kind = kind,
            failureReason = record.resultText.takeUnless { record.success }.orEmpty(),
            countryIso = record.dialCountryIso,
            callerLanguageCode = record.callerLanguageCode,
            calleeLanguageCode = record.calleeLanguageCode
        )
    }

internal fun dialRecentRestorablePhoneNumber(
    phoneNumber: String,
    countryIso: String
): String {
    val trimmed = phoneNumber.trim()
    if (
        trimmed.isBlank() ||
        trimmed.startsWith("+") ||
        trimmed.startsWith("00") ||
        trimmed.any { it == '*' || it == '#' }
    ) {
        return trimmed
    }
    val country = resolveLocatedDialCountry(countryIso) ?: return trimmed
    val parsed = parseContactDialNumber(trimmed, country.iso)
    return if (parsed is ContactDialNumberResult.Supported) {
        "${country.dialCode}${parsed.nationalNumber}"
    } else {
        trimmed
    }
}

internal fun dialContactDisplayName(
    phoneNumber: String,
    contacts: List<DialContactEntry>
): String {
    val target = phoneNumber.filter(Char::isDigit)
    if (target.isBlank()) return ""
    return contacts.firstOrNull { contact ->
        val candidate = contact.phoneNumber.filter(Char::isDigit)
        candidate == target ||
            (minOf(candidate.length, target.length) >= 7 &&
                (candidate.endsWith(target) || target.endsWith(candidate)))
    }?.displayName?.trim().orEmpty()
}

private fun dialRecentDisplayName(title: String, number: String): String =
    title.removePrefix("普通通话 ")
        .removePrefix("实时翻译 ")
        .removePrefix("翻译通话 ")
        .takeUnless { it == number }
        .orEmpty()

private fun parseDialDurationSeconds(value: String): Long {
    val parts = value.split(':').mapNotNull(String::toLongOrNull)
    return when (parts.size) {
        2 -> parts[0] * 60 + parts[1]
        3 -> parts[0] * 3_600 + parts[1] * 60 + parts[2]
        else -> 0
    }
}
