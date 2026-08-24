package com.vvtech.aiassistant.features.assistant_home

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.core.model.AssistantMessageRequest
import com.vvtech.aiassistant.core.model.ContactResolutionPayload
import com.vvtech.aiassistant.data.repository.AssistantContainer
import com.vvtech.aiassistant.domain.usecase.LoadAssistantSessionUseCase
import com.vvtech.aiassistant.domain.usecase.SendAssistantTurnUseCase
import com.vvtech.aiassistant.domain.usecase.StartRealtimeSessionUseCase
import com.vvtech.aiassistant.domain.usecase.StopRealtimeSessionUseCase
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.location.FusedLocationProvider
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AssistantHomeUiState(
    val taskId: String? = null,
    val title: String = "Task Assistant",
    val subtitle: String = "What would you like me to handle today?",
    val sceneType: String = "GENERAL",
    val taskStatus: String = "INIT",
    val messages: List<AssistantMessageItem> = emptyList(),
    val loading: Boolean = false,
    val sending: Boolean = false,
    val error: String? = null,
    val draft: String = "",
    val userContext: UserContextPayload? = null,
    val locationSummary: String = "Getting location...",
    val locating: Boolean = false,
    val voiceConnecting: Boolean = false,
    val voiceActive: Boolean = false,
    val voiceHint: String = currentAppText("也可以直接用实时语音和我说", "You can also talk to me by voice"),
    val voiceError: String? = null,
    val voiceSessionId: String? = null
)

private data class PendingContactLookup(
    val originalText: String,
    val contactName: String
)

class AssistantHomeViewModel : ViewModel() {

    private val repository = AssistantContainer.repository
    private val loadAssistantSession = LoadAssistantSessionUseCase(repository)
    private val sendAssistantTurn = SendAssistantTurnUseCase(repository)
    private val _uiState = MutableStateFlow(AssistantHomeUiState())
    val uiState: StateFlow<AssistantHomeUiState> = _uiState.asStateFlow()
    private val voiceRuntimeController = AssistantHomeVoiceRuntimeController(
        AssistantHomeVoiceRuntimeDeps(
            uiState = _uiState,
            scope = viewModelScope,
            startRealtimeSession = StartRealtimeSessionUseCase(repository),
            stopRealtimeSession = StopRealtimeSessionUseCase(repository),
            userIdProvider = { DEFAULT_USER_ID }
        )
    )

    private var initialized = false
    private var locationInitialized = false
    private var pendingContactLookup: PendingContactLookup? = null

    fun initialize() {
        if (initialized) return
        initialized = true
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching { loadAssistantSession(DEFAULT_USER_ID) }
                .onSuccess { applySession(it) }
                .onFailure { throwable ->
                    _uiState.update { state ->
                        state.copy(
                            loading = false,
                            error = throwable.message ?: currentAppText("会话加载失败", "Failed to load session")
                        )
                    }
                }
        }
    }

    fun updateDraft(value: String) {
        _uiState.update { it.copy(draft = value) }
    }

    fun ensureLocationLoaded(context: Context) {
        if (locationInitialized) return
        locationInitialized = true
        refreshLocation(context)
    }

    fun refreshLocation(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(locating = true, locationSummary = "Getting location...") }
            val result = runCatching { FusedLocationProvider(context.applicationContext).locateOnce() }
            result.onSuccess { location ->
                _uiState.update {
                    it.copy(
                        userContext = if (location.success) location.userContext else null,
                        locationSummary = if (location.summary.isBlank()) "Location updated" else location.summary,
                        locating = false
                    )
                }
            }.onFailure { throwable ->
                _uiState.update {
                    it.copy(
                        userContext = null,
                        locating = false,
                        locationSummary = throwable.message ?: "Location failed. General recommendations will be used."
                    )
                }
            }
        }
    }

    fun onLocationPermissionDenied() {
        _uiState.update {
            it.copy(
                userContext = null,
                locating = false,
                locationSummary = "Location permission is unavailable. General recommendations will be used."
            )
        }
    }

    fun onAudioPermissionDenied() {
        voiceRuntimeController.onAudioPermissionDenied()
    }

    fun sendCurrentDraft(
        context: Context,
        hasContactsPermission: Boolean,
        requestContactsPermission: () -> Unit
    ) {
        sendText(_uiState.value.draft, context, hasContactsPermission, requestContactsPermission)
    }

    fun sendText(
        text: String,
        context: Context,
        hasContactsPermission: Boolean,
        requestContactsPermission: () -> Unit
    ) {
        val trimmed = text.trim()
        if (trimmed.isBlank() || _uiState.value.sending) return

        val contactCandidate = DeviceContactResolver.extractCallContactCandidate(trimmed)
        if (contactCandidate != null && !DeviceContactResolver.containsPhone(trimmed)) {
            pushOptimisticUserMessage(trimmed)
            if (!hasContactsPermission) {
                pendingContactLookup = PendingContactLookup(trimmed, contactCandidate.contactName)
                requestContactsPermission()
                return
            }
            resolveContactAndSend(
                context = context.applicationContext,
                originalText = trimmed,
                contactName = contactCandidate.contactName
            )
            return
        }

        pushOptimisticUserMessage(trimmed)
        dispatchAssistantTurn(
            AssistantMessageRequest(
                userId = DEFAULT_USER_ID,
                taskId = _uiState.value.taskId,
                message = trimmed,
                userContext = _uiState.value.userContext
            )
        )
    }

    fun onContactsPermissionResult(context: Context, granted: Boolean) {
        val pending = pendingContactLookup ?: return
        pendingContactLookup = null
        if (granted) {
            resolveContactAndSend(
                context = context.applicationContext,
                originalText = pending.originalText,
                contactName = pending.contactName
            )
            return
        }

        dispatchAssistantTurn(
            AssistantMessageRequest(
                userId = DEFAULT_USER_ID,
                taskId = _uiState.value.taskId,
                message = pending.originalText,
                userContext = _uiState.value.userContext,
                contactResolution = ContactResolutionPayload(
                    contactName = pending.contactName,
                    status = "PERMISSION_DENIED"
                )
            )
        )
    }

    fun toggleVoice(
        context: Context,
        hasAudioPermission: Boolean,
        requestAudioPermission: () -> Unit
    ) = voiceRuntimeController.toggle(context, hasAudioPermission, requestAudioPermission)

    private fun resolveContactAndSend(
        context: Context,
        originalText: String,
        contactName: String
    ) {
        viewModelScope.launch {
            runCatching {
                DeviceContactResolver(context).findPhoneByDisplayName(contactName)
            }.onSuccess { result ->
                val resolution = if (result.found && !result.phoneNumber.isNullOrBlank()) {
                    ContactResolutionPayload(
                        contactName = result.contactName,
                        phoneNumber = result.phoneNumber,
                        status = "FOUND"
                    )
                } else {
                    ContactResolutionPayload(
                        contactName = contactName,
                        status = "NOT_FOUND"
                    )
                }
                dispatchAssistantTurn(
                    AssistantMessageRequest(
                        userId = DEFAULT_USER_ID,
                        taskId = _uiState.value.taskId,
                        message = originalText,
                        userContext = _uiState.value.userContext,
                        contactResolution = resolution
                    )
                )
            }.onFailure {
                dispatchAssistantTurn(
                    AssistantMessageRequest(
                        userId = DEFAULT_USER_ID,
                        taskId = _uiState.value.taskId,
                        message = originalText,
                        userContext = _uiState.value.userContext,
                        contactResolution = ContactResolutionPayload(
                            contactName = contactName,
                            status = "PERMISSION_DENIED"
                        )
                    )
                )
            }
        }
    }

    private fun dispatchAssistantTurn(request: AssistantMessageRequest) {
        _uiState.update { state -> state.copy(sending = true, error = null) }
        viewModelScope.launch {
            runCatching {
                sendAssistantTurn(request)
            }.onSuccess { applySession(it) }
                .onFailure { throwable ->
                    _uiState.update { state ->
                        state.copy(
                            sending = false,
                            error = throwable.message ?: currentAppText("消息发送失败", "Failed to send message")
                        )
                    }
                }
        }
    }

    private fun pushOptimisticUserMessage(text: String) {
        _uiState.update { state ->
            state.copy(
                error = null,
                draft = "",
                messages = state.messages + optimisticUserMessage(text)
            )
        }
    }

    fun triggerAction(action: AssistantActionChip) {
        if (_uiState.value.sending) return
        viewModelScope.launch {
            _uiState.update { it.copy(sending = true, error = null) }
            runCatching {
                sendAssistantTurn(
                    AssistantMessageRequest(
                        userId = DEFAULT_USER_ID,
                        taskId = _uiState.value.taskId,
                        actionId = action.actionId,
                        actionLabel = action.label,
                        userContext = _uiState.value.userContext
                    )
                )
            }.onSuccess { applySession(it) }
                .onFailure { throwable ->
                    _uiState.update { state ->
                        state.copy(
                            sending = false,
                            error = throwable.message ?: currentAppText("操作执行失败", "Failed to perform action")
                        )
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null, voiceError = null) }
    }

    private fun applySession(session: com.vvtech.aiassistant.core.model.AssistantSessionResponse) {
        _uiState.update { state ->
            state.copy(
                taskId = session.session.taskId,
                title = session.session.title,
                subtitle = session.session.subtitle ?: "What would you like me to handle today?",
                sceneType = session.session.sceneType,
                taskStatus = session.session.taskStatus,
                messages = session.messages,
                loading = false,
                sending = false,
                error = null
            )
        }
    }

    private fun optimisticUserMessage(text: String): AssistantMessageItem {
        return AssistantMessageItem(
            messageId = "local-${System.currentTimeMillis()}",
            type = "user_text",
            role = "user",
            text = text,
            title = null,
            subtitle = null,
            statusText = null
        )
    }

    override fun onCleared() {
        voiceRuntimeController.release()
        super.onCleared()
    }

    companion object {
        val DEFAULT_USER_ID: String
            get() = AccountIdentityProvider.accountId
    }
}
