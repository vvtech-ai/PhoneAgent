package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class TaskConversationBackgroundPauseStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {
    fun applyBackgroundPause() {
        uiState.update {
            TaskConversationBackgroundPauseReducer.apply(it)
        }
    }
}
