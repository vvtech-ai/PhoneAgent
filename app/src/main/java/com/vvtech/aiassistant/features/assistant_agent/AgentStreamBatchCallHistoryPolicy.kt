package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalPolicy
import com.vvtech.aiassistant.features.assistant_tasks.parseTaskCallDialogueDetail

internal data class AgentStreamBatchCallResultHistoryInput(
    val sessionId: String?,
    val batchCallResult: BatchCallResultPayload?,
    val resultStatusText: String
)

internal object AgentStreamBatchCallHistoryPolicy {
    fun localHistoryEntries(
        input: AgentStreamBatchCallResultHistoryInput
    ): List<AgentCallResultHistoryEntry> {
        val safeSessionId = input.sessionId?.trim().orEmpty()
        val result = input.batchCallResult
        if (safeSessionId.isBlank() || result == null) return emptyList()
        val batchFingerprint = batchCallResultFingerprint(result)
        return result.items.mapIndexed { index, item ->
            item.toHistoryEntry(
                sessionId = safeSessionId,
                batchFingerprint = batchFingerprint,
                index = index,
                fallbackStatusText = input.resultStatusText
            )
        }
    }

    private fun BatchCallItemResultPayload.toHistoryEntry(
        sessionId: String,
        batchFingerprint: String,
        index: Int,
        fallbackStatusText: String
    ): AgentCallResultHistoryEntry {
        val success = !TaskBatchCallFinalPolicy.needsUserConfirmation(this)
        val statusText = headline.trim().ifBlank {
            if (success) currentAppText("任务完成", "Task Complete") else currentAppText("未完成", "Incomplete")
        }
        val transcriptLines = batchItemTranscriptLines(this)
        val detailText = detail.trim()
        val safeItemId = itemId.trim().ifBlank { "item_${index + 1}" }
        return AgentCallResultHistoryEntry(
            taskId = sessionId,
            callId = "batch:$batchFingerprint:$safeItemId",
            title = targetName.trim().ifBlank { phoneNumber.trim().ifBlank { currentAppText("AI通话", "AI Call") } },
            status = statusText.ifBlank { fallbackStatusText },
            style = if (success) StatusStyle.Success else StatusStyle.Failure,
            metaDetail = batchItemMetaDetail(this, fallbackStatusText),
            finalState = true,
            phoneNumber = phoneNumber.trim(),
            resultText = detailText.ifBlank { statusText.ifBlank { fallbackStatusText } },
            transcript = transcriptLines
        )
    }

    private fun batchItemMetaDetail(
        item: BatchCallItemResultPayload,
        fallbackStatusText: String
    ): String {
        return listOf(item.detail, item.headline, item.transcript.orEmpty(), fallbackStatusText)
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString("\n")
    }

    private fun batchCallResultFingerprint(result: BatchCallResultPayload): String {
        val source = buildString {
            append(result.status.trim())
            append('\n')
            append(result.headline.trim())
            result.items.forEach { item ->
                append('\n')
                append(item.itemId.trim())
                append('|')
                append(item.targetName.trim())
                append('|')
                append(item.phoneNumber.trim())
                append('|')
                append(item.status.trim())
                append('|')
                append(item.headline.trim())
                append('|')
                append(item.detail.trim())
                append('|')
                append(item.attemptCount)
                append('|')
                append(item.recalled)
                append('|')
                append(item.abnormal)
                append('|')
                append(item.transcript.orEmpty().trim())
            }
        }
        return Integer.toHexString(source.hashCode())
    }

    private fun batchItemTranscriptLines(item: BatchCallItemResultPayload): List<TranscriptLine> {
        val raw = item.transcript?.trim().orEmpty()
        if (raw.isBlank()) return emptyList()
        val parsed = parseTaskCallDialogueDetail(raw)
        return parsed.ifEmpty { listOf(TranscriptLine(TranscriptRole.Remote, raw)) }
    }
}
