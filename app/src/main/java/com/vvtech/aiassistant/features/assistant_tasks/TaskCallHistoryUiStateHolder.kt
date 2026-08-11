package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class TaskCallHistoryUiStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {
    fun clearHistory() {
        uiState.update {
            it.copy(
                historyLoading = false,
                historyError = null,
                historyRecords = emptyList()
            )
        }
    }

    fun showHistoryRecords(records: List<HistoryRecord>) {
        uiState.update {
            it.copy(
                historyLoading = false,
                historyError = null,
                historyRecords = records
            )
        }
    }

    fun markHistoryLoading() {
        uiState.update {
            it.copy(historyLoading = true, historyError = null)
        }
    }

    fun showHistoryError(message: String) {
        uiState.update {
            it.copy(historyError = message)
        }
    }
}
