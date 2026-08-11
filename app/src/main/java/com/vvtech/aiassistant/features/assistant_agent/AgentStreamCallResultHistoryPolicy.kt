package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.model.UserContextPayload

internal data class AgentCallResultHistoryEntry(
    val taskId: String,
    val callId: String,
    val title: String,
    val status: String,
    val style: StatusStyle,
    val metaDetail: String,
    val finalState: Boolean,
    val phoneNumber: String = "",
    val resultText: String = "",
    val transcript: List<TranscriptLine> = emptyList()
)

internal object AgentStreamCallResultHistoryPolicy {
    fun localHistoryEntry(
        sessionId: String?,
        currentCallPage: CallPageData,
        callResult: CallResultPayload?,
        resultStatusText: String,
        resolvedConversationStatus: String
    ): AgentCallResultHistoryEntry? {
        val safeSessionId = sessionId?.trim().orEmpty()
        if (safeSessionId.isBlank()) return null
        val metadata = callResult?.metadata.orEmpty()
        val detail = listOf(
            callResult?.detail.orEmpty(),
            metadata["agentReason"].orEmpty(),
            metadata["resultReason"].orEmpty()
        )
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString("\n")
        return AgentCallResultHistoryEntry(
            taskId = safeSessionId,
            callId = metadata["callId"].orEmpty(),
            title = currentCallPage.name.ifBlank {
                callResult?.headline?.trim()?.takeIf { it.isNotBlank() } ?: "AI代打结果"
            },
            status = resultStatusText,
            style = if (resolvedConversationStatus == "COMPLETED") StatusStyle.Success else StatusStyle.Failure,
            metaDetail = detail.ifBlank { resultStatusText },
            finalState = true,
            phoneNumber = currentCallPage.sub,
            resultText = callResult?.detail.orEmpty().ifBlank { resultStatusText },
            transcript = currentCallPage.transcript
        )
    }

    fun agentContextLogMessage(
        action: String,
        sessionId: String,
        voice: Boolean,
        context: UserContextPayload
    ): String {
        val contact = context.defaultReservationContact
        val deviceContactSummary = context.deviceContacts.orEmpty()
            .joinToString("|") { item ->
                val last4 = item.phoneNumber?.takeLast(4).orEmpty()
                "${item.contactName}:${item.status}:$last4"
            }
        val ocrTextChars = context.ocrAttachments.orEmpty().sumOf { it.fullText.length }
        return "action=$action session=$sessionId voice=$voice " +
            "latPresent=${context.lat != null} lngPresent=${context.lng != null} " +
            "lat=${formatCoordinate(context.lat)} lng=${formatCoordinate(context.lng)} " +
            "adcode=${context.adcode.orEmpty()} city=${context.city.orEmpty()} district=${context.district.orEmpty()} " +
            "time=${context.currentTime?.isoDateTime.orEmpty()} timezone=${context.currentTime?.timezone.orEmpty()} " +
            "contactPresent=${contact != null} contactName=${contact?.name.orEmpty()} " +
            "contactPhoneLast4=${contact?.phone?.takeLast(4).orEmpty()} " +
            "deviceContacts=${context.deviceContacts?.size ?: 0} deviceContactSummary=$deviceContactSummary " +
            "ocrAttachments=${context.ocrAttachments?.size ?: 0} ocrTextChars=$ocrTextChars"
    }

    fun applyCallResultLogMessage(
        responseSessionId: String,
        currentSessionId: String?,
        callResult: CallResultPayload?,
        resolvedConversationStatus: String,
        resultStatusText: String
    ): String {
        val metadata = callResult?.metadata.orEmpty()
        return "Apply CALL_RESULT responseSessionId=$responseSessionId " +
            "currentSessionId=${currentSessionId.orEmpty()} " +
            "status=${callResult?.status.orEmpty()} " +
            "agentOutcome=${reportOutcomeFromMetadata(metadata)} " +
            "resultCode=${metadata["resultCode"].orEmpty()} " +
            "resultReason=${metadata["resultReason"].orEmpty().take(120)} " +
            "agentReason=${metadata["agentReason"].orEmpty().take(120)} " +
            "callId=${metadata["callId"].orEmpty()} " +
            "taskId=${metadata["taskId"].orEmpty()} " +
            "resolvedTaskStatus=$resolvedConversationStatus " +
            "statusText=$resultStatusText " +
            "metadataKeys=${metadata.keys.joinToString(",")}"
    }

    private fun reportOutcomeFromMetadata(metadata: Map<String, String>): String {
        val keys = listOf("agentOutcome", "reportCallOutcome", "callOutcome", "outcome", "agent_outcome")
        return keys
            .asSequence()
            .mapNotNull { key -> metadata[key]?.trim()?.takeIf { it.isNotBlank() } }
            .firstOrNull()
            .orEmpty()
    }

    private fun formatCoordinate(value: Double?): String {
        return value?.let { "%.6f".format(it) }.orEmpty()
    }
}
