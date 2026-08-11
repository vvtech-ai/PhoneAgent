package com.vvtech.aiassistant.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.location.FusedLocationProvider
import com.vvtech.aiassistant.model.ChatMessage
import com.vvtech.aiassistant.model.MessageRole
import com.vvtech.aiassistant.model.ReservationSlot
import com.vvtech.aiassistant.model.UserContextPayload
import com.vvtech.aiassistant.repository.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ConversationUiState(
    val taskId: String? = null,
    val status: String = "INIT",
    val messages: List<ChatMessage> = listOf(
        ChatMessage(MessageRole.AI, "直接告诉我订餐需求，我会先补齐最少信息，再继续后续流程。")
    ),
    val slot: ReservationSlot = ReservationSlot(),
    val missingFields: List<String> = emptyList(),
    val complete: Boolean = false,
    val loading: Boolean = false,
    val error: String? = null,
    val readyToOpenRestaurants: Boolean = false,
    val userContext: UserContextPayload? = null,
    val locationSummary: String = "正在获取定位...",
    val locating: Boolean = false
)

class ConversationViewModel : ViewModel() {

    private val repository = AppContainer.taskRepository
    private val _uiState = MutableStateFlow(ConversationUiState())
    val uiState: StateFlow<ConversationUiState> = _uiState.asStateFlow()

    private var initializedTaskId: String? = null
    private var locationInitialized = false

    fun initialize(taskId: String?) {
        val normalizedTaskId = taskId?.takeIf { it.isNotBlank() && it != "new" }
        if (initializedTaskId == normalizedTaskId) {
            return
        }
        initializedTaskId = normalizedTaskId
        if (normalizedTaskId == null) {
            val currentLocation = _uiState.value.userContext
            val currentLocationSummary = _uiState.value.locationSummary
            _uiState.value = ConversationUiState(
                userContext = currentLocation,
                locationSummary = currentLocationSummary,
                locating = false
            )
            return
        }
        loadTask(normalizedTaskId)
    }

    fun ensureLocationLoaded(context: Context) {
        if (locationInitialized) {
            return
        }
        locationInitialized = true
        refreshLocation(context)
    }

    fun refreshLocation(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(locating = true, locationSummary = "正在获取定位...") }
            val result = runCatching { FusedLocationProvider(context.applicationContext).locateOnce() }
            result.onSuccess { location ->
                _uiState.update {
                    it.copy(
                        userContext = if (location.success) location.userContext else null,
                        locationSummary = if (location.summary.isBlank()) "定位已更新" else location.summary,
                        locating = false
                    )
                }
            }.onFailure { throwable ->
                _uiState.update {
                    it.copy(
                        userContext = null,
                        locating = false,
                        locationSummary = throwable.message ?: "定位失败，将使用通用推荐。"
                    )
                }
            }
        }
    }

    fun onLocationPermissionDenied() {
        locationInitialized = true
        _uiState.update {
            it.copy(
                userContext = null,
                locating = false,
                locationSummary = "未授权定位，将使用通用推荐。"
            )
        }
    }

    fun sendMessage(content: String) {
        if (content.isBlank() || _uiState.value.loading) {
            return
        }
        val userMessage = ChatMessage(MessageRole.USER, content.trim())
        _uiState.update { state ->
            state.copy(
                loading = true,
                error = null,
                messages = state.messages + userMessage
            )
        }
        viewModelScope.launch {
            val currentTaskId = _uiState.value.taskId
            val currentUserContext = _uiState.value.userContext
            val result = runCatching {
                if (currentTaskId.isNullOrBlank()) {
                    repository.createTask(TaskListViewModel.DEFAULT_USER_ID, content.trim(), currentUserContext)
                } else {
                    repository.chat(currentTaskId, content.trim(), currentUserContext)
                }
            }
            result.onSuccess { response ->
                _uiState.update { state ->
                    state.copy(
                        taskId = response.taskId,
                        status = response.status,
                        slot = response.slot,
                        missingFields = response.missingFields,
                        complete = response.complete,
                        loading = false,
                        readyToOpenRestaurants = false,
                        messages = state.messages + ChatMessage(MessageRole.AI, response.aiMessage)
                    )
                }
            }.onFailure { throwable ->
                _uiState.update { state ->
                    state.copy(
                        loading = false,
                        error = throwable.message ?: "消息发送失败"
                    )
                }
            }
        }
    }

    fun confirm() {
        val taskId = _uiState.value.taskId ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching { repository.confirm(taskId, true) }
                .onSuccess { response ->
                    _uiState.update { state ->
                        state.copy(
                            status = response.status,
                            slot = response.slot,
                            complete = true,
                            loading = false,
                            readyToOpenRestaurants = response.readyForRestaurant,
                            messages = state.messages + ChatMessage(MessageRole.AI, response.summary)
                        )
                    }
                }
                .onFailure { throwable ->
                    _uiState.update { it.copy(loading = false, error = throwable.message ?: "确认失败") }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun loadTask(taskId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching { repository.getTaskDetail(taskId) }
                .onSuccess { detail ->
                    val summaryMessage = buildString {
                        append("已加载任务 ")
                        append(detail.taskId)
                        append("，当前状态为 ")
                        append(detail.status)
                        append("。")
                        if (!detail.finalResult.isNullOrBlank()) {
                            append(" ")
                            append(detail.finalResult)
                        }
                    }
                    _uiState.value = ConversationUiState(
                        taskId = detail.taskId,
                        status = detail.status,
                        messages = listOf(ChatMessage(MessageRole.AI, summaryMessage)),
                        slot = detail.slot,
                        missingFields = emptyList(),
                        complete = hasCoreFields(detail.slot),
                        loading = false,
                        readyToOpenRestaurants = detail.status == "SEARCH_RESTAURANTS"
                            || (detail.status == "READY" && !detail.selectedRestaurantId.isNullOrBlank()),
                        userContext = _uiState.value.userContext,
                        locationSummary = _uiState.value.locationSummary,
                        locating = false
                    )
                }
                .onFailure { throwable ->
                    _uiState.update { it.copy(loading = false, error = throwable.message ?: "任务加载失败") }
                }
        }
    }

    private fun hasCoreFields(slot: ReservationSlot): Boolean {
        return !slot.reservationTime.isNullOrBlank()
            && slot.partySize != null
            && (!slot.restaurantName.isNullOrBlank() || !slot.locationIntent.isNullOrBlank())
    }
}
