package com.vvtech.aiassistant.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.repository.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class TaskListUiState(
    val loading: Boolean = false,
    val tasks: List<TaskListItem> = emptyList(),
    val error: String? = null
)

class TaskListViewModel : ViewModel() {

    private val repository = AppContainer.taskRepository
    private val _uiState = MutableStateFlow(TaskListUiState())
    val uiState: StateFlow<TaskListUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh(userId: String = DEFAULT_USER_ID) {
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching { repository.listTasks(userId) }
                .onSuccess { tasks ->
                    _uiState.update { it.copy(loading = false, tasks = tasks, error = null) }
                }
                .onFailure { throwable ->
                    _uiState.update { it.copy(loading = false, error = throwable.message ?: "任务加载失败") }
                }
        }
    }

    companion object {
        val DEFAULT_USER_ID: String
            get() = AccountIdentityProvider.accountId
    }
}
