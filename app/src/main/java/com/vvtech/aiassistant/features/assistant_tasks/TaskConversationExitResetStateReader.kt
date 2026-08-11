package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.StateFlow

internal class TaskConversationExitResetStateReader(
    private val uiState: StateFlow<Index9AssistantUiState>
) {
    fun currentState(): Index9AssistantUiState = uiState.value
}
