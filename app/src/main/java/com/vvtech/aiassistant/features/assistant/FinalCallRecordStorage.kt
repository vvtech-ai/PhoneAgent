package com.vvtech.aiassistant.features.assistant

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

private data class PersistedFinalCallRecord(
    val title: String? = null,
    val status: String? = null,
    val meta: String? = null,
    val success: Boolean,
    val occurredAtMillis: Long? = null,
    val phoneNumber: String? = null,
    val dateText: String? = null,
    val startTimeText: String? = null,
    val endTimeText: String? = null,
    val durationText: String? = null,
    val resultText: String? = null,
    val transcript: List<PersistedTranscriptLine>? = null,
    val taskId: String? = null,
    val callId: String? = null,
    val callKind: String? = null,
    val dialCountryIso: String? = null,
    val callerLanguageCode: String? = null,
    val calleeLanguageCode: String? = null
)

private data class PersistedTranscriptLine(
    val role: String? = null,
    val text: String? = null
)

internal fun finalCallRecordsStorageKey(accountId: String): String {
    val normalized = accountId.trim().ifBlank { "guest" }
    return "final_call_records_$normalized"
}

internal fun encodeFinalCallRecords(records: List<FinalCallRecord>): String {
    return Gson().toJson(
        records.map { record ->
            PersistedFinalCallRecord(
                title = record.title,
                status = record.status,
                meta = record.meta,
                success = record.success,
                occurredAtMillis = record.occurredAtMillis,
                phoneNumber = record.phoneNumber,
                dateText = record.dateText,
                startTimeText = record.startTimeText,
                endTimeText = record.endTimeText,
                durationText = record.durationText,
                resultText = record.resultText,
                transcript = record.transcript.map {
                    PersistedTranscriptLine(role = it.role.name, text = it.text)
                },
                taskId = record.taskId,
                callId = record.callId,
                callKind = record.callKind.name,
                dialCountryIso = record.dialCountryIso,
                callerLanguageCode = record.callerLanguageCode,
                calleeLanguageCode = record.calleeLanguageCode
            )
        }
    )
}

internal fun decodeFinalCallRecords(raw: String?): List<FinalCallRecord> {
    val text = raw.orEmpty().trim()
    if (text.isBlank()) return emptyList()
    return runCatching {
        val type = object : TypeToken<List<PersistedFinalCallRecord>>() {}.type
        val records: List<PersistedFinalCallRecord> = Gson().fromJson(text, type) ?: emptyList()
        records.mapNotNull { item ->
            val title = item.title.orEmpty().trim()
            val status = item.status.orEmpty().trim()
            val meta = item.meta.orEmpty().trim()
            if (title.isBlank() || status.isBlank() || meta.isBlank()) {
                null
            } else {
                FinalCallRecord(
                    title = title,
                    status = status,
                    meta = meta,
                    success = item.success,
                    occurredAtMillis = item.occurredAtMillis?.takeIf { it > 0L },
                    phoneNumber = item.phoneNumber.orEmpty().trim(),
                    dateText = item.dateText.orEmpty().trim(),
                    startTimeText = item.startTimeText.orEmpty().trim(),
                    endTimeText = item.endTimeText.orEmpty().trim(),
                    durationText = item.durationText.orEmpty().trim(),
                    resultText = item.resultText.orEmpty().trim(),
                    transcript = item.transcript.orEmpty().mapNotNull { it.toTranscriptLine() },
                    taskId = item.taskId.orEmpty().trim(),
                    callId = item.callId.orEmpty().trim(),
                    callKind = runCatching {
                        DialCallKind.valueOf(item.callKind.orEmpty())
                    }.getOrDefault(DialCallKind.AGENT),
                    dialCountryIso = item.dialCountryIso.orEmpty().trim(),
                    callerLanguageCode = item.callerLanguageCode.orEmpty().trim(),
                    calleeLanguageCode = item.calleeLanguageCode.orEmpty().trim()
                )
            }
        }
    }.getOrDefault(emptyList())
}

private fun PersistedTranscriptLine.toTranscriptLine(): TranscriptLine? {
    val text = text.orEmpty().trim()
    if (text.isBlank()) return null
    val role = runCatching { TranscriptRole.valueOf(role.orEmpty()) }
        .getOrDefault(TranscriptRole.Note)
    return TranscriptLine(role = role, text = text)
}
