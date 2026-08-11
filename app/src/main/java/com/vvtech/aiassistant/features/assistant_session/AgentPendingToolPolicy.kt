package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object AgentPendingToolPolicy {
    fun pendingToolCallIdForUserTurn(state: Index9AssistantUiState): String? {
        return when {
            state.agentCallSpec != null -> null
            state.agentPermissionRequest != null -> null
            else -> state.agentPendingToolCallId
        }
    }
}
