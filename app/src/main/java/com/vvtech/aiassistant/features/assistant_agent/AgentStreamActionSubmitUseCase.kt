package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.flow.Flow

internal class AgentStreamActionSubmitUseCase(
    private val streamProvider: (AgentChatRequest) -> Flow<AgentStreamEvent>
) {
    constructor(repository: AssistantRepository) : this(
        streamProvider = repository::agentChatStream
    )

    fun stream(
        request: AgentStreamActionSubmitRequest,
        userContext: UserContextPayload
    ): Flow<AgentStreamEvent> {
        return streamProvider(
            AgentChatRequest(
                sessionId = request.sessionId,
                actionId = request.actionId,
                actionPayload = request.actionPayload,
                userContext = userContext,
                channel = request.channel,
                userId = request.userId,
                commandId = request.identity.commandId,
                idempotencyKey = request.identity.idempotencyKey,
                traceId = request.identity.traceId,
                languageCode = null,
                responseLanguage = null,
            )
        )
    }
}
