package com.vvtech.aiassistant.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.CallTaskResponse
import com.vvtech.aiassistant.model.Restaurant
import com.vvtech.aiassistant.repository.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class RestaurantSelectionUiState(
    val taskId: String = "",
    val status: String = "",
    val restaurants: List<Restaurant> = emptyList(),
    val selectedRestaurantId: String? = null,
    val loading: Boolean = false,
    val calling: Boolean = false,
    val callResult: CallTaskResponse? = null,
    val error: String? = null
)

class RestaurantSelectionViewModel : ViewModel() {

    private val repository = AppContainer.taskRepository
    private val _uiState = MutableStateFlow(RestaurantSelectionUiState())
    val uiState: StateFlow<RestaurantSelectionUiState> = _uiState.asStateFlow()

    private var initializedTaskId: String? = null

    fun initialize(taskId: String) {
        if (initializedTaskId == taskId) {
            return
        }
        initializedTaskId = taskId
        loadRestaurants(taskId)
    }

    fun selectRestaurant(restaurantId: String) {
        val taskId = _uiState.value.taskId
        if (taskId.isBlank()) {
            return
        }
        if (_uiState.value.selectedRestaurantId == restaurantId && _uiState.value.status == "READY") {
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching { repository.selectRestaurant(taskId, restaurantId) }
                .onSuccess { response ->
                    _uiState.update {
                        it.copy(
                            loading = false,
                            selectedRestaurantId = restaurantId,
                            status = response.status
                        )
                    }
                }
                .onFailure { throwable ->
                    _uiState.update {
                        it.copy(
                            loading = false,
                            error = throwable.message ?: currentAppText("餐厅选择失败", "Failed to select restaurant")
                        )
                    }
                }
        }
    }

    fun callRestaurant() {
        val taskId = _uiState.value.taskId
        if (taskId.isBlank()) {
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(calling = true, error = null) }
            runCatching { repository.callTask(taskId) }
                .onSuccess { response ->
                    _uiState.update {
                        it.copy(
                            calling = false,
                            status = response.status,
                            callResult = response
                        )
                    }
                }
                .onFailure { throwable ->
                    _uiState.update {
                        it.copy(
                            calling = false,
                            error = throwable.message ?: currentAppText("外呼失败", "Failed to start call")
                        )
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun loadRestaurants(taskId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null, taskId = taskId) }
            runCatching { repository.getRestaurants(taskId) }
                .onSuccess { response ->
                    _uiState.update {
                        it.copy(
                            taskId = response.taskId,
                            status = response.status,
                            restaurants = response.restaurants,
                            selectedRestaurantId = response.selectedRestaurantId,
                            loading = false
                        )
                    }
                }
                .onFailure { throwable ->
                    _uiState.update {
                        it.copy(
                            loading = false,
                            error = throwable.message ?: currentAppText(
                                "餐厅列表加载失败",
                                "Failed to load restaurant list"
                            )
                        )
                    }
                }
        }
    }
}
