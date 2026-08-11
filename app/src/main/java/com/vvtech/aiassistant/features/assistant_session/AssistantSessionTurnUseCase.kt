package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantMessageRequest
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.ContactResolutionPayload
import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.core.model.TextSessionStartRequest
import com.vvtech.aiassistant.core.model.TextTurnRequest
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.model.UserContextPayload

internal data class AssistantTextSessionStartInput(
    val userId: String,
    val userContext: UserContextPayload?,
    val languageCode: String?
)

internal data class AssistantTextTurnInput(
    val userId: String,
    val taskId: String?,
    val message: String? = null,
    val actionId: String? = null,
    val actionLabel: String? = null,
    val userContext: UserContextPayload?,
    val contactResolution: ContactResolutionPayload? = null,
    val languageCode: String?
)

internal data class AssistantVoiceMessageInput(
    val userId: String,
    val taskId: String?,
    val startFresh: Boolean,
    val message: String,
    val userContext: UserContextPayload?,
    val contactResolution: ContactResolutionPayload?,
    val structuredUnderstanding: StructuredAssistantUnderstanding? = null,
    val assistantResponseText: String? = null,
    val languageCode: String?
)

internal class AssistantSessionTurnUseCase(
    private val repository: AssistantRepository
) {
    suspend fun startTextSession(input: AssistantTextSessionStartInput): AssistantSessionResponse {
        return repository.startTextSession(
            TextSessionStartRequest(
                userId = input.userId,
                userContext = input.userContext,
                languageCode = input.languageCode
            )
        )
    }

    suspend fun sendTextTurn(input: AssistantTextTurnInput): AssistantSessionResponse {
        return repository.sendTextTurn(
            TextTurnRequest(
                userId = input.userId,
                taskId = input.taskId,
                message = input.message,
                actionId = input.actionId,
                actionLabel = input.actionLabel,
                userContext = input.userContext,
                contactResolution = input.contactResolution,
                languageCode = input.languageCode
            )
        )
    }

    suspend fun sendVoiceMessage(input: AssistantVoiceMessageInput): AssistantSessionResponse {
        return repository.sendMessage(
            AssistantMessageRequest(
                userId = input.userId,
                taskId = input.taskId,
                startFresh = input.startFresh,
                message = input.message,
                userContext = input.userContext,
                contactResolution = input.contactResolution,
                structuredUnderstanding = input.structuredUnderstanding,
                assistantResponseText = input.assistantResponseText,
                languageCode = input.languageCode
            )
        )
    }
}
