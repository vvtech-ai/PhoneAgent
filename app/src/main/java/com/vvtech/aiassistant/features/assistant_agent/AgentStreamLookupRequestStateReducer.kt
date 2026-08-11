package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object AgentStreamLookupRequestStateReducer {
    fun contactLookupRequest(
        state: Index9AssistantUiState,
        response: AgentChatResponse
    ): Index9AssistantUiState {
        return state.copy(
            stage = AssistantStage.Clarifying,
            processingTurn = true,
            error = null,
            status = "AI处理中",
            agentOptions = null,
            agentQuestions = null,
            agentPermissionRequest = null,
            agentDocumentRequest = null,
            agentDocumentImporting = false,
            agentPendingToolCallId = response.pendingToolCallId,
            agentLookupContactPhone = response.lookupContactPhone.orEmpty(),
            agentLookupContactInFlight = true
        )
    }

    fun deviceContactsLookupRequest(
        state: Index9AssistantUiState,
        response: AgentChatResponse
    ): Index9AssistantUiState? {
        val payload = response.lookupDeviceContactsByNames
        if (payload == null || payload.names.isEmpty() || response.pendingToolCallId.isNullOrBlank()) {
            return null
        }
        return state.copy(
            stage = AssistantStage.Clarifying,
            processingTurn = true,
            error = null,
            status = "AI处理中",
            agentOptions = null,
            agentQuestions = null,
            agentPermissionRequest = null,
            agentDocumentRequest = null,
            agentDocumentImporting = false,
            agentPendingToolCallId = response.pendingToolCallId,
            agentLookupDeviceContactsRequest = payload,
            agentLookupDeviceContactsInFlight = true,
            agentDeviceContactSelection = null
        )
    }
}
