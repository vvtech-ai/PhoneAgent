package com.vvtech.aiassistant.features.assistant_timeline

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.domain.task.ReceiptField
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.domain.task.TaskReceiptTransportStatusPolicy

/** Builds one durable display item for each call attempt without merging sibling attempts by task id. */
internal object CallAttemptTimelineProjector {
    fun project(events: List<ConversationLedgerEvent>): List<ConversationTimelineItem> {
        return events.asSequence()
            .filter { it.schemaVersion == 1 && it.callAttemptId?.isNotBlank() == true }
            .groupBy { requireNotNull(it.callAttemptId).trim() }
            .values
            .mapNotNull(::projectAttempt)
            .sortedBy { it.ledgerSequence }
    }

    private fun projectAttempt(events: List<ConversationLedgerEvent>): ConversationTimelineItem? {
        val ordered = events.sortedBy { it.sequence }
        val callFacts = ordered.filter { it.stableType() in CALL_FACT_TYPES }
        if (callFacts.isEmpty()) return null

        val attemptId = callFacts.firstNotNullOf { it.callAttemptId?.trim()?.takeIf(String::isNotBlank) }
        val requested = callFacts.firstOrNull { it.stableType() == StableConversationLedgerEventType.CALL_REQUESTED }
        val started = callFacts.lastOrNull { it.stableType() == StableConversationLedgerEventType.CALL_STARTED }
        val terminal = callFacts.lastOrNull { it.stableType() in PHYSICAL_TERMINAL_TYPES }
        val reported = callFacts.lastOrNull { it.stableType() == StableConversationLedgerEventType.CALL_OUTCOME_REPORTED }
        val toolRequest = ordered.lastOrNull { it.stableType() == StableConversationLedgerEventType.TOOL_REQUESTED }
        val toolResult = ordered.lastOrNull { it.stableType() == StableConversationLedgerEventType.TOOL_RESULT_RECORDED }
        val resultObject = toolResult?.payload?.objectField("result")
        val metadata = resultObject?.objectField("metadata")
        val callReceipt = terminal?.payload?.objectField("callReceipt")
            ?: started?.payload?.objectField("callReceipt")
        val displaySource = reported ?: terminal ?: started ?: requested ?: return null
        val orderSource = requested ?: started ?: terminal ?: reported ?: return null

        val physicalStatus = when {
            reported != null -> TaskReceiptTransportStatusPolicy.normalize(reported.payload.text("outcome"))
            terminal != null -> callReceipt?.text("callState").orEmpty()
                .ifBlank { terminal.stableType()?.wireName.orEmpty() }
            started != null -> StableConversationLedgerEventType.CALL_STARTED.wireName
            requested != null -> StableConversationLedgerEventType.CALL_REQUESTED.wireName
            else -> StableConversationLedgerEventType.CALL_OUTCOME_REPORTED.wireName
        }
        val targetName = callReceipt?.text("targetName").orEmpty()
            .ifBlank { toolRequest?.payload?.objectField("arguments")?.text("targetName").orEmpty() }
            .orEmpty().ifBlank { requested?.payload?.text("recipientRef").orEmpty() }
        val headline = reported?.payload?.text("headline").orEmpty()
            .ifBlank { terminal?.payload?.text("summary").orEmpty() }
            .ifBlank { resultObject?.text("headline").orEmpty() }
            .ifBlank { physicalStatus }
        val detail = callReceipt?.text("resultReason").orEmpty()
            .ifBlank { callReceipt?.text("statusMessage").orEmpty() }
            .ifBlank { reported?.payload?.text("reason").orEmpty() }
            .ifBlank { terminal?.payload?.text("reason").orEmpty() }
            .ifBlank { resultObject?.text("detail").orEmpty() }
        val transcript = callReceipt?.text("dialogueDetail").orEmpty()
            .ifBlank { metadata?.text("dialogueTranscript").orEmpty() }
            .ifBlank { resultObject?.text("transcript").orEmpty() }
            .ifBlank { terminal?.payload?.text("transcript").orEmpty() }
            .takeIf(String::isNotBlank)
        val receiptFields = reported?.payload?.receiptFields().orEmpty()

        return ConversationTimelineItem(
            itemId = "ledger:call:$attemptId",
            sessionId = displaySource.sessionId,
            taskId = callFacts.firstNotNullOfOrNull { it.taskId?.takeIf(String::isNotBlank) },
            orderKey = TimelineOrderKey(messageIndex = 0),
            payload = ConversationTimelinePayload.SingleCallReceipt(
                callAttemptId = attemptId,
                receipt = TaskReceiptItemState(
                    itemId = attemptId,
                    targetName = targetName,
                    status = physicalStatus,
                    headline = headline,
                    detail = detail,
                    transcript = transcript,
                    receiptFields = receiptFields,
                ),
                callId = callReceipt?.text("callId")?.takeIf(String::isNotBlank)
                    ?: terminal?.callId?.takeIf(String::isNotBlank),
                phoneNumber = callReceipt?.text("phoneNumber").orEmpty(),
                createdAt = callReceipt?.text("createdAt")?.takeIf(String::isNotBlank),
                updatedAt = callReceipt?.text("updatedAt")?.takeIf(String::isNotBlank),
            ),
            ledgerSequence = orderSource.sequence,
            ledgerEventId = displaySource.eventId,
        )
    }

    private fun ConversationLedgerEvent.stableType(): StableConversationLedgerEventType? =
        (type as? ConversationLedgerEventType.Known)?.stable

    private fun JsonObject.objectField(name: String): JsonObject? =
        get(name)?.takeUnless { it.isJsonNull }?.takeIf { it.isJsonObject }?.asJsonObject

    private fun JsonObject.text(name: String): String = get(name)?.primitiveText().orEmpty()

    private fun JsonObject.receiptFields(): List<ReceiptField> =
        get("receiptFields")
            ?.takeUnless { it.isJsonNull }
            ?.takeIf { it.isJsonArray }
            ?.asJsonArray
            ?.mapNotNull { element ->
                element.takeIf { it.isJsonObject }
                    ?.asJsonObject
                    ?.toReceiptField()
            }
            .orEmpty()

    private fun JsonObject.toReceiptField(): ReceiptField? {
        val key = text("key")
        val label = text("label")
        val value = text("value")
        if (key.isBlank() || label.isBlank() || value.isBlank()) return null
        return ReceiptField(key = key, label = label, value = value)
    }

    private fun JsonElement.primitiveText(): String? =
        takeUnless { isJsonNull }?.takeIf { isJsonPrimitive }?.asJsonPrimitive?.let { primitive ->
            when {
                primitive.isString -> primitive.asString
                primitive.isBoolean -> primitive.asBoolean.toString()
                primitive.isNumber -> primitive.asNumber.toString()
                else -> null
            }
        }

    private val PHYSICAL_TERMINAL_TYPES = setOf(
        StableConversationLedgerEventType.CALL_COMPLETED,
        StableConversationLedgerEventType.CALL_FAILED,
        StableConversationLedgerEventType.CALL_CANCELLED,
        StableConversationLedgerEventType.CALL_REJECTED,
    )
    private val CALL_FACT_TYPES = PHYSICAL_TERMINAL_TYPES + setOf(
        StableConversationLedgerEventType.CALL_REQUESTED,
        StableConversationLedgerEventType.CALL_STARTED,
        StableConversationLedgerEventType.CALL_OUTCOME_REPORTED,
    )
}
