package com.vvtech.aiassistant.features.assistant_timeline

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.domain.task.BatchTaskReceiptState
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.google.gson.JsonObject

/**
 * The only translation from durable wire facts to the legacy timeline projection.
 * Unknown name/schema facts remain in the ledger cache and advance the reducer cursor,
 * but never become invented display items.
 */
object ConversationLedgerTimelineMapper {
    fun map(event: ConversationLedgerEvent): LedgerTimelineMapping {
        val stableType = (event.type as? ConversationLedgerEventType.Known)?.stable
            ?: return LedgerTimelineMapping.Skipped(event.eventId, event.sequence, "unknown_event_type")
        if (event.schemaVersion != SUPPORTED_SCHEMA_VERSION) {
            return LedgerTimelineMapping.Skipped(event.eventId, event.sequence, "unsupported_schema")
        }
        rejectedCallConfirmationRemoval(stableType, event)?.let { removal ->
            return LedgerTimelineMapping.Rendered(event.eventId, event.sequence, removal)
        }
        val payload = payloadFor(stableType, event)
            ?: return LedgerTimelineMapping.Skipped(event.eventId, event.sequence, "non_display_event")
        val itemId = when (payload) {
            is ConversationTimelinePayload.BatchCallReceipt ->
                "ledger:batch:${payload.batchAttemptId}"
            is ConversationTimelinePayload.CallConfirmation ->
                callConfirmationItemId(payload.toolCallId, event.eventId)
            else -> "ledger:${event.eventId}"
        }
        return LedgerTimelineMapping.Rendered(event.eventId, event.sequence, ConversationTimelineEvent.Upsert(
            ConversationTimelineItem(
                itemId = itemId,
                sessionId = event.sessionId,
                taskId = event.taskId,
                orderKey = TimelineOrderKey(messageIndex = 0),
                payload = payload,
                createdAtEpochMs = null,
                ledgerSequence = event.sequence,
                ledgerEventId = event.eventId,
            )
        ))
    }

    private fun rejectedCallConfirmationRemoval(
        type: StableConversationLedgerEventType,
        event: ConversationLedgerEvent,
    ): ConversationTimelineEvent.Remove? {
        if (type != StableConversationLedgerEventType.TOOL_RESULT_RECORDED) return null
        if (event.payload.string("toolName") != "makeCall") return null
        if (event.payload.string("resultStatus").lowercase() !in REJECTED_TOOL_RESULT_STATUSES) return null
        val toolCallId = event.payload.string("toolCallId").trim()
        if (toolCallId.isBlank()) return null
        return ConversationTimelineEvent.Remove(callConfirmationItemId(toolCallId, event.eventId))
    }

    private fun payloadFor(
        type: StableConversationLedgerEventType,
        event: ConversationLedgerEvent,
    ): ConversationTimelinePayload? = when (type) {
        StableConversationLedgerEventType.USER_TURN_ACCEPTED ->
            ConversationTimelinePayload.UserMessage(event.payload.string("text"))
        StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED ->
            batchReceipt(event) ?: ConversationTimelinePayload.AssistantMessage(event.payload.string("text"))
        StableConversationLedgerEventType.TOOL_REQUESTED ->
            ShowOptionsTimelineProjection.map(event.payload)
                ?: InteractiveToolTimelineProjection.map(event.payload)
                ?: callConfirmation(event)
        StableConversationLedgerEventType.TOOL_RESULT_RECORDED -> batchReceipt(event)
        StableConversationLedgerEventType.OCR_IMAGE_COMMITTED ->
            OcrImageTimelineProjection.map(event.payload)
        StableConversationLedgerEventType.CALL_COMPLETED,
        StableConversationLedgerEventType.CALL_FAILED,
        StableConversationLedgerEventType.CALL_CANCELLED,
        StableConversationLedgerEventType.CALL_REJECTED -> ConversationTimelinePayload.SingleCallReceipt(
            callAttemptId = event.callAttemptId ?: event.eventId,
            receipt = TaskReceiptItemState(
                itemId = event.callAttemptId ?: event.eventId,
                targetName = event.payload.string("recipientRef"),
                status = event.payload.string("resultCode").ifBlank { type.wireName },
                headline = event.payload.string("summary", type.wireName),
                detail = event.payload.string("reason"),
            ),
        )
        else -> null
    }

    private fun callConfirmation(event: ConversationLedgerEvent): ConversationTimelinePayload.CallConfirmation? {
        if (event.payload.string("toolName") != "makeCall") return null
        val arguments = event.payload.objectField("arguments") ?: return null
        val toolCallId = event.payload.string("toolCallId").trim().takeIf(String::isNotBlank)
        val callSpec = CallSpecPayload(
            phoneNumber = arguments.string("phoneNumber"),
            scene = arguments.string("scene"),
            targetName = arguments.string("targetName"),
            primaryGoal = arguments.string("primaryGoal"),
            summaryLines = arguments.stringList("summaryLines"),
            negotiationRules = arguments.stringList("negotiationRules").takeIf(List<String>::isNotEmpty),
            boundaries = arguments.stringList("boundaries").takeIf(List<String>::isNotEmpty),
        )
        val hasVisibleContent = callSpec.targetName.isNotBlank() ||
            callSpec.phoneNumber.isNotBlank() ||
            callSpec.primaryGoal.isNotBlank() ||
            callSpec.summaryLines.isNotEmpty()
        return callSpec.takeIf { hasVisibleContent }
            ?.let { ConversationTimelinePayload.CallConfirmation(it, toolCallId) }
    }

    internal fun explicitBatchId(event: ConversationLedgerEvent): String? =
        batchResultObject(event)?.string("batchId")?.takeIf(String::isNotBlank)

    private fun batchReceipt(event: ConversationLedgerEvent): ConversationTimelinePayload.BatchCallReceipt? {
        val batch = batchResultObject(event) ?: return null
        val items = batch.get("items")
            ?.takeIf { it.isJsonArray }
            ?.asJsonArray
            ?.mapIndexedNotNull { index, element ->
                val item = element.takeIf { it.isJsonObject }?.asJsonObject ?: return@mapIndexedNotNull null
                TaskReceiptItemState(
                    itemId = item.string("itemId").ifBlank { "${event.eventId}:$index" },
                    targetName = item.string("targetName"),
                    status = item.string("status"),
                    headline = item.string("headline"),
                    detail = item.string("detail"),
                    attemptCount = item.string("attemptCount").toIntOrNull() ?: 1,
                    recalled = item.string("recalled").toBooleanStrictOrNull() ?: false,
                    abnormal = item.string("abnormal").toBooleanStrictOrNull() ?: false,
                    transcript = item.string("transcript").takeIf(String::isNotBlank),
                )
            }
            .orEmpty()
        if (items.isEmpty()) return null
        val batchId = batch.string("batchId").ifBlank { event.eventId }
        return ConversationTimelinePayload.BatchCallReceipt(
            batchAttemptId = batchId,
            receipt = BatchTaskReceiptState(
                batchId = batchId,
                status = batch.string("status"),
                headline = batch.string("headline"),
                items = items,
            )
        )
    }

    private fun batchResultObject(event: ConversationLedgerEvent): JsonObject? =
        event.payload.objectField("batchCallResult")
            ?: event.payload.objectField("result")?.objectField("batchCallResult")

    private fun JsonObject.objectField(name: String): JsonObject? =
        get(name)?.takeUnless { it.isJsonNull }?.takeIf { it.isJsonObject }?.asJsonObject

    private fun JsonObject.string(name: String, default: String = ""): String =
        get(name)?.primitiveText() ?: default

    private fun JsonObject.stringList(name: String): List<String> =
        get(name)
            ?.takeUnless { it.isJsonNull }
            ?.takeIf { it.isJsonArray }
            ?.asJsonArray
            ?.mapNotNull { it.primitiveText()?.takeIf(String::isNotBlank) }
            .orEmpty()

    private fun com.google.gson.JsonElement.primitiveText(): String? =
        takeUnless { isJsonNull }?.takeIf { isJsonPrimitive }?.asJsonPrimitive?.let { primitive ->
            when {
                primitive.isString -> primitive.asString
                primitive.isBoolean -> primitive.asBoolean.toString()
                primitive.isNumber -> primitive.asNumber.toString()
                else -> null
            }
        }

    private const val SUPPORTED_SCHEMA_VERSION = 1
    private val REJECTED_TOOL_RESULT_STATUSES = setOf("policy_rejected", "rejected")

    private fun callConfirmationItemId(toolCallId: String?, fallbackEventId: String): String =
        toolCallId
            ?.trim()
            ?.takeIf(String::isNotBlank)
            ?.let { "ledger:call-confirmation:$it" }
            ?: "ledger:$fallbackEventId"
}

sealed interface LedgerTimelineMapping {
    val eventId: String
    val sequence: Long

    data class Rendered(
        override val eventId: String,
        override val sequence: Long,
        val event: ConversationTimelineEvent,
    ) : LedgerTimelineMapping

    data class Skipped(
        override val eventId: String,
        override val sequence: Long,
        val reason: String,
    ) : LedgerTimelineMapping
}

data class LedgerTimelineState(
    val items: List<ConversationTimelineItem> = emptyList(),
    val processedEventIds: Set<String> = emptySet(),
    val cursor: Long = 0L,
)

object ConversationLedgerTimelineReducer {
    fun reduce(state: LedgerTimelineState, mapping: LedgerTimelineMapping): LedgerTimelineState {
        if (mapping.eventId in state.processedEventIds) return state
        val nextItems = (mapping as? LedgerTimelineMapping.Rendered)
            ?.let { ConversationTimelineReducer.reduce(state.items, it.event) } ?: state.items
        return state.copy(
            items = nextItems,
            processedEventIds = state.processedEventIds + mapping.eventId,
            cursor = maxOf(state.cursor, mapping.sequence),
        )
    }

    fun reduceAll(events: Iterable<ConversationLedgerEvent>): LedgerTimelineState {
        val ordered = events.sortedBy { it.sequence }
        val supersededCommands = ordered.recoverySupersededCommandIds()
        val base = ordered.fold(LedgerTimelineState()) { state, event ->
            val mapping = if (
                event.commandId in supersededCommands &&
                event.isSupersedableModelFact()
            ) {
                LedgerTimelineMapping.Skipped(event.eventId, event.sequence, "recovery_superseded")
            } else if (event.isCallAttemptFact()) {
                LedgerTimelineMapping.Skipped(event.eventId, event.sequence, "call_attempt_projected")
            } else {
                ConversationLedgerTimelineMapper.map(event)
            }
            reduce(state, mapping)
        }
        val explicitBatchIds = ordered.mapNotNull(ConversationLedgerTimelineMapper::explicitBatchId).toSet()
        val projectedCalls = CallAttemptTimelineProjector.project(ordered)
            .filterNot { it.taskId in explicitBatchIds }
        return base.copy(items = ConversationTimelineReducer.reduceAll(
            base.items,
            projectedCalls.map(ConversationTimelineEvent::Upsert),
        ))
    }

    private fun List<ConversationLedgerEvent>.recoverySupersededCommandIds(): Set<String> {
        val cancellationSequenceByCommand = mapNotNull { event ->
            event.commandId
                ?.takeIf(String::isNotBlank)
                ?.takeIf {
                    event.stableType() == StableConversationLedgerEventType.RUN_CANCELLED &&
                        event.payload.get("stage")
                            ?.takeIf { value -> value.isJsonPrimitive }
                            ?.asString == "recovery_revision"
                }
                ?.let { it to event.sequence }
        }.groupBy({ it.first }, { it.second })
            .mapValues { (_, sequences) -> sequences.min() }
        return cancellationSequenceByCommand.filter { (commandId, cancellationSequence) ->
            none { event ->
                event.commandId == commandId &&
                    event.sequence < cancellationSequence &&
                    event.stableType() == StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED
            }
        }.keys
    }

    private fun ConversationLedgerEvent.isSupersedableModelFact(): Boolean = when (stableType()) {
        StableConversationLedgerEventType.USER_TURN_ACCEPTED,
        StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED,
        StableConversationLedgerEventType.TOOL_REQUESTED,
        StableConversationLedgerEventType.TOOL_RESULT_RECORDED -> true
        else -> false
    }

    private fun ConversationLedgerEvent.stableType(): StableConversationLedgerEventType? =
        (type as? ConversationLedgerEventType.Known)?.stable

    private fun ConversationLedgerEvent.isCallAttemptFact(): Boolean = when (
        stableType()
    ) {
        StableConversationLedgerEventType.CALL_REQUESTED,
        StableConversationLedgerEventType.CALL_STARTED,
        StableConversationLedgerEventType.CALL_COMPLETED,
        StableConversationLedgerEventType.CALL_FAILED,
        StableConversationLedgerEventType.CALL_CANCELLED,
        StableConversationLedgerEventType.CALL_REJECTED,
        StableConversationLedgerEventType.CALL_OUTCOME_REPORTED -> schemaVersion == 1
        else -> false
    }
}
