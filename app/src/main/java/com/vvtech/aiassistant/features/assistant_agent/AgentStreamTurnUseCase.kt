package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentCommandIdentity
import com.vvtech.aiassistant.core.model.AgentCommandKind
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.flow.Flow

internal data class AgentStreamTurnUseCaseRequest(
    val sessionId: String,
    val message: String,
    val pendingToolCallId: String?,
    val channel: String,
    val userId: String,
    val initialSkillId: String? = null,
    val initialOpening: String? = null,
    val selectedContact: SelectedContactTaskContext? = null,
    val languageCode: String,
    val responseLanguage: String,
    val identity: AgentCommandIdentity = AgentCommandIdentity.newIntent(
        sessionId,
        AgentCommandKind.UserTurn,
    ),
    val supersedesCommandId: String? = null,
)

internal class AgentStreamTurnUseCase(
    private val streamProvider: (AgentChatRequest) -> Flow<AgentStreamEvent>
) {
    constructor(repository: AssistantRepository) : this(
        streamProvider = repository::agentChatStream
    )

    fun stream(
        request: AgentStreamTurnUseCaseRequest,
        userContext: UserContextPayload
    ): Flow<AgentStreamEvent> {
        return streamProvider(
            AgentChatRequest(
                sessionId = request.sessionId,
                message = agentBackendMessageForLanguage(
                    message = request.message,
                    languageCode = request.languageCode
                ),
                userContext = userContext,
                pendingToolCallId = request.pendingToolCallId,
                channel = request.channel,
                userId = request.userId,
                initialSkillId = request.initialSkillId,
                initialOpening = request.initialOpening,
                commandId = request.identity.commandId,
                idempotencyKey = request.identity.idempotencyKey,
                traceId = request.identity.traceId,
                supersedesCommandId = request.supersedesCommandId,
                selectedContact = request.selectedContact,
                languageCode = null,
                responseLanguage = null,
            )
        )
    }
}
