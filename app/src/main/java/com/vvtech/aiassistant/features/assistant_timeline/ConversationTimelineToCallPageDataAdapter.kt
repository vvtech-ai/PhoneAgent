package com.vvtech.aiassistant.features.assistant_timeline

import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole

/**
 * Projects only the latest single-call item for the legacy call page. Conversation
 * history must use [ConversationTimelineToClarificationStepsAdapter] instead.
 */
object ConversationTimelineToCallPageDataAdapter {
    fun adaptLatestSingleReceipt(
        items: List<ConversationTimelineItem>,
        fallback: CallPageData,
        preserveFallbackTranscript: Boolean = false,
    ): CallPageData {
        val receipt = items
            .asSequence()
            .sortedWith(compareBy<ConversationTimelineItem> { it.orderKey }.thenBy { it.itemId })
            .mapNotNull { it.payload as? ConversationTimelinePayload.SingleCallReceipt }
            .lastOrNull()
            ?: return fallback
        val item = receipt.receipt
        val projectedTranscript = buildList {
            item.transcript
                ?.lineSequence()
                ?.map { line -> line.trim() }
                ?.filter(String::isNotBlank)
                ?.forEach { add(it.toTranscriptLine()) }
            item.headline.takeIf { it.isNotBlank() }?.let { add(TranscriptLine(TranscriptRole.Note, it)) }
            item.detail.takeIf { it.isNotBlank() && it != item.headline }?.let {
                add(TranscriptLine(TranscriptRole.Note, it))
            }
        }
        val hasDialogue = projectedTranscript.any { it.role != TranscriptRole.Note }
        return CallPageData(
            name = item.targetName.ifBlank { fallback.name },
            sub = receipt.phoneNumber.ifBlank { fallback.sub },
            status = item.status,
            transcript = when {
                preserveFallbackTranscript ->
                    mergeTranscriptByOccurrence(fallback.transcript, projectedTranscript)
                hasDialogue -> projectedTranscript
                else -> fallback.transcript.ifEmpty { projectedTranscript }
            },
            callResult = item.toLegacyCallResult(
                callAttemptId = receipt.callAttemptId,
                callId = receipt.callId,
            ),
        )
    }

    private fun mergeTranscriptByOccurrence(
        existing: List<TranscriptLine>,
        incoming: List<TranscriptLine>,
    ): List<TranscriptLine> {
        if (existing.isEmpty()) return incoming
        val remainingExistingOccurrences = existing
            .groupingBy(::transcriptKey)
            .eachCount()
            .toMutableMap()
        val missingIncoming = incoming.filter { line ->
            val key = transcriptKey(line)
            val remaining = remainingExistingOccurrences[key] ?: 0
            if (remaining <= 0) {
                true
            } else {
                if (remaining == 1) {
                    remainingExistingOccurrences.remove(key)
                } else {
                    remainingExistingOccurrences[key] = remaining - 1
                }
                false
            }
        }
        return existing + missingIncoming
    }

    private fun transcriptKey(line: TranscriptLine): Pair<TranscriptRole, String> =
        line.role to line.text.trim()

    private fun String.toTranscriptLine(): TranscriptLine = when {
        startsWith("AI：") || startsWith("AI:", ignoreCase = true) || startsWith("assistant:", ignoreCase = true) ->
            TranscriptLine(TranscriptRole.Assistant, substringAfter('：', substringAfter(':')).trim())
        startsWith("对方：") || startsWith("对方:") ||
            startsWith("callee:", ignoreCase = true) ||
            startsWith("merchant:", ignoreCase = true) ||
            startsWith("remote:", ignoreCase = true) ->
            TranscriptLine(TranscriptRole.Remote, substringAfter('：', substringAfter(':')).trim())
        else -> TranscriptLine(TranscriptRole.Note, this)
    }
}
