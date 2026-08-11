package com.vvtech.aiassistant.domain.conversation

import com.google.gson.JsonObject

/** Durable, account-owned timeline fact. Payload is retained raw for forward compatibility. */
data class ConversationLedgerEvent(
    val eventId: String,
    val sessionId: String,
    val sequence: Long,
    val type: ConversationLedgerEventType,
    val schemaVersion: Int,
    val idempotencyKey: String,
    val occurredAt: String,
    val committedAt: String,
    val payload: JsonObject,
    val commandId: String? = null,
    val traceId: String? = null,
    val taskId: String? = null,
    val callAttemptId: String? = null,
    val callId: String? = null,
    val providerCallId: String? = null,
)

sealed interface ConversationLedgerEventType {
    val wireName: String

    data class Known(val stable: StableConversationLedgerEventType) : ConversationLedgerEventType {
        override val wireName: String = stable.wireName
    }

    data class Unknown(override val wireName: String) : ConversationLedgerEventType

    companion object {
        fun fromWire(wireName: String): ConversationLedgerEventType =
            StableConversationLedgerEventType.values().firstOrNull { it.wireName == wireName }
                ?.let(::Known) ?: Unknown(wireName)
    }
}

enum class StableConversationLedgerEventType(val wireName: String) {
    USER_TURN_ACCEPTED("USER_TURN_ACCEPTED"),
    ASSISTANT_TURN_COMMITTED("ASSISTANT_TURN_COMMITTED"),
    TOOL_REQUESTED("TOOL_REQUESTED"),
    TOOL_RESULT_RECORDED("TOOL_RESULT_RECORDED"),
    CALL_REQUESTED("CALL_REQUESTED"),
    CALL_STARTED("CALL_STARTED"),
    CALL_COMPLETED("CALL_COMPLETED"),
    CALL_FAILED("CALL_FAILED"),
    CALL_CANCELLED("CALL_CANCELLED"),
    CALL_REJECTED("CALL_REJECTED"),
    CALL_OUTCOME_REPORTED("CALL_OUTCOME_REPORTED"),
    CONVERSATION_INTERRUPTED("CONVERSATION_INTERRUPTED"),
    CONVERSATION_RESUMED("CONVERSATION_RESUMED"),
    OCR_IMAGE_COMMITTED("OCR_IMAGE_COMMITTED"),
    RUN_FAILED("RUN_FAILED"),
    RUN_CANCELLED("RUN_CANCELLED"),
}

data class ConversationTimelineProjection(
    val conversationStatus: String,
    val conversationContinuable: Boolean,
    val pendingToolRestorable: Boolean,
    val migrationStatus: String,
    val projectedThroughSequence: Long,
)

data class ConversationTimelinePage(
    val sessionId: String,
    val schemaVersion: Int,
    val ledgerHeadSequence: Long,
    val requestedAfterSequence: Long?,
    val firstSequence: Long?,
    val lastSequence: Long?,
    val nextAfterSequence: Long?,
    val hasMore: Boolean,
    val projection: ConversationTimelineProjection,
    val events: List<ConversationLedgerEvent>,
)
