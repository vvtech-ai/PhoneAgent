package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineRepository
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Durable SSE facts enter the same repository used by restore; text deltas stay transient. */
internal class AgentStreamTimelineCommittedHandler(
    private val repository: ConversationTimelineRepository,
    private val accountIdProvider: () -> String,
    private val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    private val acceptTimelineProjection: (String, List<ConversationTimelineItem>) -> Unit = { _, _ -> },
) {
    private val mergeMutex = Mutex()

    suspend fun merge(event: AgentStreamEvent.TimelineCommitted): TimelineSnapshotUiProjection =
        mergeMutex.withLock {
            TimelineSnapshotUiProjector.project(
                repository.mergeCommittedEvent(accountIdProvider(), event.event)
            )
        }

    fun applyProjection(projection: TimelineSnapshotUiProjection): Boolean {
        acceptTimelineProjection(projection.sessionId, projection.timelineItems)
        updateState(projection::reduceAfterStreamOwnershipReleased)
        return projection.hasTerminalCallReceipt
    }

    /** Pulls the durable timeline after the stream has ended before its terminal receipt arrived. */
    suspend fun sync(sessionId: String): TimelineSnapshotUiProjection =
        mergeMutex.withLock {
            TimelineSnapshotUiProjector.project(
                repository.sync(accountIdProvider(), sessionId)
            )
        }
}
