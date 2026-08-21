package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.data.model.ContactLookupResultRequest
import com.vvtech.aiassistant.data.model.DeviceContactsLookupResultRequest
import com.vvtech.aiassistant.data.repository.AssistantRepository

internal class AgentStreamContactLookupResultUseCase(
    private val contactLookupResultProvider: suspend (ContactLookupResultRequest) -> AgentChatResponse,
    private val deviceContactsLookupResultProvider: suspend (DeviceContactsLookupResultRequest) -> AgentChatResponse
) {
    constructor(repository: AssistantRepository) : this(
        contactLookupResultProvider = repository::postContactLookupResult,
        deviceContactsLookupResultProvider = repository::postDeviceContactsLookupResult
    )

    suspend fun submitContactLookupResult(
        request: AgentContactLookupResultSubmitRequest
    ): AgentChatResponse {
        return contactLookupResultProvider(
            ContactLookupResultRequest(
                sessionId = request.sessionId,
                pendingToolCallId = request.pendingToolCallId,
                userId = request.userId,
                result = request.result,
                languageCode = null,
                responseLanguage = null
            )
        )
    }

    suspend fun submitDeviceContactsLookupResult(
        request: AgentDeviceContactsLookupResultSubmitRequest
    ): AgentChatResponse {
        return deviceContactsLookupResultProvider(
            DeviceContactsLookupResultRequest(
                sessionId = request.sessionId,
                pendingToolCallId = request.pendingToolCallId,
                userId = request.userId,
                results = request.results,
                channel = request.channel,
                languageCode = null,
                responseLanguage = null
            )
        )
    }
}
