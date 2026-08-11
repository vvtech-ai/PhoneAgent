package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.data.repository.timeline.TimelineLegacyNoLedgerException
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineRepository
import com.vvtech.aiassistant.data.repository.timeline.TimelineUnavailableException

internal class AssistantConversationRestoreUseCase(
    private val repository: AssistantRepository,
    private val timelineRepository: ConversationTimelineRepository,
    private val accountIdProvider: () -> String,
    private val log: (String) -> Unit,
) {
    suspend fun loadSnapshot(
        sessionId: String,
        rawStatusProvider: (String) -> String
    ): AssistantConversationRestoreSnapshot {
        val detail = repository.getConversation(sessionId)
        return runCatching { timelineRepository.sync(accountIdProvider(), sessionId) }
            .map { timeline -> buildAssistantConversationRestoreSnapshot(detail, timeline) }
            .getOrElse { throwable ->
                if (throwable !is TimelineUnavailableException && throwable !is TimelineLegacyNoLedgerException) {
                    throw throwable
                }
                log("TIMELINE_LEGACY_FALLBACK sessionId=$sessionId reason=${throwable.javaClass.simpleName}")
                buildAssistantConversationRestoreSnapshot(detail, rawStatusProvider(detail.sessionId))
            }
    }
}
