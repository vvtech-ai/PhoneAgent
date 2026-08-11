package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class TaskReceiptStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {

    fun applyCallResultStatus(statusText: String) {
        uiState.update {
            TaskReceiptUiStateReducer.applyCallResultStatus(it, statusText)
        }
    }

    fun appendCallNote(note: String) {
        uiState.update {
            TaskReceiptUiStateReducer.appendCallNote(it, note)
        }
    }

    fun applyCallOutcomePendingDisplay(pendingText: String) {
        uiState.update {
            TaskReceiptUiStateReducer.applyCallOutcomePendingDisplay(it, pendingText)
        }
    }
}
