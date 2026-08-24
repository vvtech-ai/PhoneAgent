package com.vvtech.aiassistant.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.TaskDetailResponse
import com.vvtech.aiassistant.repository.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class TaskDetailUiState(
    val loading: Boolean = false,
    val detail: TaskDetailResponse? = null,
    val error: String? = null
)

class TaskDetailViewModel : ViewModel() {

    private val repository = AppContainer.taskRepository
    private val _uiState = MutableStateFlow(TaskDetailUiState())
    val uiState: StateFlow<TaskDetailUiState> = _uiState.asStateFlow()

    private var initializedTaskId: String? = null

    fun initialize(taskId: String) {
        if (initializedTaskId == taskId) {
            return
        }
        initializedTaskId = taskId
        refresh(taskId)
    }

    fun refresh(taskId: String = initializedTaskId.orEmpty()) {
        if (taskId.isBlank()) {
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching { repository.getTaskDetail(taskId) }
                .onSuccess { detail ->
                    _uiState.update { it.copy(loading = false, detail = detail, error = null) }
                }
                .onFailure { throwable ->
                    _uiState.update {
                        it.copy(
                            loading = false,
                            error = throwable.message ?: currentAppText("任务详情加载失败", "Failed to load task details")
                        )
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
