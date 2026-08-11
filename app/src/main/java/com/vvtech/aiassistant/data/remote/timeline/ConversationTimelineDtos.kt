package com.vvtech.aiassistant.data.remote.timeline

import com.google.gson.JsonObject

data class ConversationTimelineEventDto(
    val eventId: String,
    val sessionId: String,
    val sequence: Long,
    val eventType: String,
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

data class ConversationTimelineProjectionDto(
    val conversationStatus: String,
    val conversationContinuable: Boolean,
    val pendingToolRestorable: Boolean,
    val migrationStatus: String,
    val projectedThroughSequence: Long,
)

data class ConversationTimelinePageDto(
    val sessionId: String,
    val schemaVersion: Int,
    val ledgerHeadSequence: Long,
    val requestedAfterSequence: Long? = null,
    val firstSequence: Long? = null,
    val lastSequence: Long? = null,
    val nextAfterSequence: Long? = null,
    val hasMore: Boolean,
    val projection: ConversationTimelineProjectionDto,
    val events: List<ConversationTimelineEventDto>,
)
