package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

internal data class TaskCallSessionTranscriptMergeResult(
    val transcript: List<TranscriptLine>,
    val lastAppliedDialogueDetail: String?
)

internal fun parseTaskCallSessionUpdatedAt(value: String?): LocalDateTime? {
    val safeValue = value?.trim().orEmpty()
    if (safeValue.isBlank()) return null
    return runCatching { LocalDateTime.parse(safeValue, DateTimeFormatter.ISO_LOCAL_DATE_TIME) }
        .getOrNull()
}

internal fun parseTaskCallDialogueDetail(detail: String): List<TranscriptLine> {
    return detail
        .lineSequence()
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .mapNotNull { line ->
            when {
                line.startsWith("assistant:", ignoreCase = true) -> TranscriptLine(
                    role = TranscriptRole.Assistant,
                    text = line.substringAfter(':').trim()
                )

                line.startsWith("callee:", ignoreCase = true) -> TranscriptLine(
                    role = TranscriptRole.Remote,
                    text = line.substringAfter(':').trim()
                )

                line.startsWith("merchant:", ignoreCase = true) -> TranscriptLine(
                    role = TranscriptRole.Remote,
                    text = line.substringAfter(':').trim()
                )

                line.startsWith("remote:", ignoreCase = true) -> TranscriptLine(
                    role = TranscriptRole.Remote,
                    text = line.substringAfter(':').trim()
                )

                else -> null
            }
        }
        .filter { it.text.isNotBlank() }
        .toList()
}

internal fun taskCallSessionIsStreamingDialogueLine(line: TranscriptLine): Boolean {
    return line.role == TranscriptRole.Assistant || line.role == TranscriptRole.Remote
}

internal fun sameTaskCallSessionTranscriptLine(left: TranscriptLine, right: TranscriptLine): Boolean {
    return left.role == right.role && left.text.trim() == right.text.trim()
}

internal fun mergeTaskCallSessionTranscript(
    currentTranscript: List<TranscriptLine>,
    previousDialogueDetail: String?,
    dialogueDetail: String?
): TaskCallSessionTranscriptMergeResult {
    val normalized = dialogueDetail?.trim().orEmpty()
    if (normalized.isBlank()) {
        return TaskCallSessionTranscriptMergeResult(
            transcript = currentTranscript,
            lastAppliedDialogueDetail = null
        )
    }
    val previous = previousDialogueDetail?.trim().orEmpty()
    if (normalized == previous) {
        return TaskCallSessionTranscriptMergeResult(
            transcript = currentTranscript,
            lastAppliedDialogueDetail = previousDialogueDetail
        )
    }
    val incomingLines = parseTaskCallDialogueDetail(normalized)
    if (incomingLines.isEmpty()) {
        return TaskCallSessionTranscriptMergeResult(
            transcript = currentTranscript,
            lastAppliedDialogueDetail = normalized
        )
    }
    val merged = if (previous.isBlank() || !normalized.startsWith(previous)) {
        val preservedSeedLines = currentTranscript.filter { existing ->
            incomingLines.none { incoming -> sameTaskCallSessionTranscriptLine(incoming, existing) }
        }
        preservedSeedLines + incomingLines
    } else {
        val previousLines = parseTaskCallDialogueDetail(previous)
        currentTranscript + incomingLines.drop(previousLines.size.coerceAtMost(incomingLines.size))
    }
    return TaskCallSessionTranscriptMergeResult(
        transcript = merged,
        lastAppliedDialogueDetail = normalized
    )
}
