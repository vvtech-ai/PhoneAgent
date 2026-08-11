package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import java.time.LocalDateTime
import java.time.Duration
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.ZoneId

/** Projects terminal call receipts only; each durable callAttemptId remains a separate record. */
internal object ConversationTimelineCallHistoryAdapter {
    fun adapt(items: List<ConversationTimelineItem>): List<TaskCallHistoryEntry> = items.mapNotNull(::entry)
        .distinctBy(TaskCallHistoryEntry::callAttemptId)
        .sortedByDescending(TaskCallHistoryEntry::sortAt)

    private fun entry(item: ConversationTimelineItem): TaskCallHistoryEntry? {
        val receipt = item.payload as? ConversationTimelinePayload.SingleCallReceipt ?: return null
        val callAttemptId = receipt.callAttemptId
        val taskId = item.taskId?.takeIf { it.isNotBlank() } ?: item.sessionId ?: return null
        val state = receipt.receipt
        val normalizedStatus = state.status.trim().uppercase()
        val failed = normalizedStatus.contains("FAIL") || normalizedStatus.contains("CANCEL") || normalizedStatus.contains("REJECT")
        val finalState = normalizedStatus in TERMINAL_STATUSES || failed
        if (!finalState) return null
        val transcript = parseTaskCallDialogueDetail(state.transcript.orEmpty())
        val summary = callHistoryReceiptSummary(
            resultReason = state.detail,
            statusMessage = state.headline,
            dialogueSummary = null,
            transcript = transcript,
            success = !failed,
        )
        return TaskCallHistoryEntry(
            key = "task=$taskId|attempt=$callAttemptId", taskId = taskId, callAttemptId = callAttemptId,
            callId = receipt.callId,
            title = callHistoryDisplayTitle(state.targetName, receipt.phoneNumber), status = state.status,
            style = if (failed) StatusStyle.Failure else StatusStyle.Success,
            meta = summary, sortAt = receipt.updatedAt.toHistoryDateTime()
                ?: receipt.createdAt.toHistoryDateTime()
                ?: LocalDateTime.MIN.plusSeconds(item.ledgerSequence ?: 0L),
            finalState = finalState,
            phoneNumber = receipt.phoneNumber,
            dateText = receipt.createdAt.toHistoryDateTime()?.format(DateTimeFormatter.ofPattern("yyyy-MM-dd")).orEmpty(),
            startTimeText = receipt.createdAt.toHistoryDateTime()?.format(DateTimeFormatter.ofPattern("HH:mm")).orEmpty(),
            endTimeText = receipt.updatedAt.toHistoryDateTime()?.format(DateTimeFormatter.ofPattern("HH:mm")).orEmpty(),
            durationText = historyDuration(receipt.createdAt.toHistoryDateTime(), receipt.updatedAt.toHistoryDateTime()),
            resultText = summary,
            transcript = transcript,
        )
    }

    internal fun String?.toHistoryDateTime(): LocalDateTime? = this
        ?.trim()
        ?.takeIf(String::isNotBlank)
        ?.let { value ->
            runCatching {
                OffsetDateTime.parse(value, DateTimeFormatter.ISO_OFFSET_DATE_TIME)
                    .atZoneSameInstant(ZoneId.systemDefault())
                    .toLocalDateTime()
            }.getOrElse {
                runCatching { LocalDateTime.parse(value, DateTimeFormatter.ISO_LOCAL_DATE_TIME) }.getOrNull()
            }
        }

    internal fun historyDuration(start: LocalDateTime?, end: LocalDateTime?): String {
        if (start == null || end == null) return ""
        val seconds = Duration.between(start, end).seconds.coerceAtLeast(0)
        return "%02d:%02d".format(seconds / 60, seconds % 60)
    }

    private val TERMINAL_STATUSES = setOf(
        "COMPLETED", "SUCCESS", "DONE", "FINISHED", "ENDED", "NOT_FOUND",
        "CALL_COMPLETED", "CALL_FAILED", "CALL_CANCELLED", "CALL_REJECTED",
    )
}
