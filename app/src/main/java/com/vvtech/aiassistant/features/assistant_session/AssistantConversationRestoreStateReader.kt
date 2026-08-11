package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.StateFlow

internal class AssistantConversationRestoreStateReader(
    private val uiState: StateFlow<Index9AssistantUiState>
) {
    fun currentState(): Index9AssistantUiState = uiState.value
}
