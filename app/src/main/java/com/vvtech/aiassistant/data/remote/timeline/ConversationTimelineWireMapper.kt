package com.vvtech.aiassistant.data.remote.timeline

import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection

object ConversationTimelineWireMapper {
    fun toDomain(dto: ConversationTimelinePageDto): ConversationTimelinePage = ConversationTimelinePage(
        sessionId = dto.sessionId,
        schemaVersion = dto.schemaVersion,
        ledgerHeadSequence = dto.ledgerHeadSequence,
        requestedAfterSequence = dto.requestedAfterSequence,
        firstSequence = dto.firstSequence,
        lastSequence = dto.lastSequence,
        nextAfterSequence = dto.nextAfterSequence,
        hasMore = dto.hasMore,
        projection = dto.projection.toDomain(),
        events = dto.events.map(::toDomain),
    )

    fun toDomain(dto: ConversationTimelineEventDto): ConversationLedgerEvent = ConversationLedgerEvent(
        eventId = dto.eventId,
        sessionId = dto.sessionId,
        sequence = dto.sequence,
        type = ConversationLedgerEventType.fromWire(dto.eventType),
        schemaVersion = dto.schemaVersion,
        idempotencyKey = dto.idempotencyKey,
        occurredAt = dto.occurredAt,
        committedAt = dto.committedAt,
        payload = dto.payload,
        commandId = dto.commandId,
        traceId = dto.traceId,
        taskId = dto.taskId,
        callAttemptId = dto.callAttemptId,
        callId = dto.callId,
        providerCallId = dto.providerCallId,
    )

    fun toDto(event: ConversationLedgerEvent): ConversationTimelineEventDto = ConversationTimelineEventDto(
        eventId = event.eventId,
        sessionId = event.sessionId,
        sequence = event.sequence,
        eventType = event.type.wireName,
        schemaVersion = event.schemaVersion,
        idempotencyKey = event.idempotencyKey,
        occurredAt = event.occurredAt,
        committedAt = event.committedAt,
        payload = event.payload,
        commandId = event.commandId,
        traceId = event.traceId,
        taskId = event.taskId,
        callAttemptId = event.callAttemptId,
        callId = event.callId,
        providerCallId = event.providerCallId,
    )

    private fun ConversationTimelineProjectionDto.toDomain() = ConversationTimelineProjection(
        conversationStatus = conversationStatus,
        conversationContinuable = conversationContinuable,
        pendingToolRestorable = pendingToolRestorable,
        migrationStatus = migrationStatus,
        projectedThroughSequence = projectedThroughSequence,
    )
}
