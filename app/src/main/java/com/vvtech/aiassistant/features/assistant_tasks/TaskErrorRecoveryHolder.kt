package com.vvtech.aiassistant.features.assistant_tasks

import android.content.Context
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow

internal class TaskErrorRecoveryHolder(
    appContext: Context,
    repository: AssistantRepository,
    uiState: MutableStateFlow<Index9AssistantUiState>,
    private val conversationList: MutableStateFlow<List<ConversationListItem>>,
    private val scope: CoroutineScope,
    private val currentAgentSessionId: () -> String?,
    private val pendingAiCallLaunch: () -> Boolean,
    private val currentVoiceLanguage: () -> VoiceLanguage,
    private val cancelTextProcessingStatusProgress: () -> Unit,
    private val closeTaskVoiceRealtime: (String) -> Unit,
    private val hasActiveAiCallContext: () -> Boolean,
    private val restartCallSessionPolling: () -> Unit,
    private val loadConversations: () -> Unit,
    private val log: (String) -> Unit
) {
    private val uiStateHolder = TaskErrorRecoveryUiStateHolder(uiState)
    private val networkStateHandler = TaskErrorRecoveryNetworkStateHandler(
        uiStateHolder = uiStateHolder,
        pendingAiCallLaunch = pendingAiCallLaunch,
        currentVoiceLanguage = currentVoiceLanguage,
        cancelTextProcessingStatusProgress = cancelTextProcessingStatusProgress,
        closeTaskVoiceRealtime = closeTaskVoiceRealtime,
        log = log
    )
    private val pendingController = TaskErrorRecoveryPendingControllerFactory.create(
        appContext = appContext,
        repository = repository,
        conversationList = conversationList,
        log = log
    )
    private val confirmController = TaskErrorRecoveryConfirmController(
        uiStateHolder = uiStateHolder,
        scope = scope,
        currentAgentSessionId = currentAgentSessionId,
        rememberPendingExecutionErrorRecovered = pendingController::rememberPendingExecutionErrorRecovered,
        syncPendingExecutionErrorRecoveredSessions = { syncPendingExecutionErrorRecoveredSessions() },
        log = log
    )
    private val networkRetryController = TaskErrorRecoveryNetworkRetryController(
        networkRegistrar = TaskErrorRecoveryNetworkCallbackRegistrar(appContext),
        scope = scope,
        pendingExecutionErrorExitSessions = ::pendingExecutionErrorExitSessions,
        pendingExecutionErrorRecoveredSessions = ::pendingExecutionErrorRecoveredSessions,
        syncPendingExecutionErrorExitSessions = { syncPendingExecutionErrorExitSessions() },
        syncPendingExecutionErrorRecoveredSessions = { syncPendingExecutionErrorRecoveredSessions() },
        hasActiveAiCallContext = hasActiveAiCallContext,
        restartCallSessionPolling = restartCallSessionPolling,
        loadConversations = loadConversations,
        log = log
    )

    internal fun applyNetworkTaskErrorState(raw: String? = null) {
        networkStateHandler.applyNetworkTaskErrorState(raw)
    }

    internal fun markTaskErrorRecoveryInProgress(status: String = "EXECUTION_ERROR") {
        uiStateHolder.markRecoveryInProgress(status)
    }

    internal fun markTaskErrorRecoveryConfirmed(reason: String, promoteToRunning: Boolean = true) {
        confirmController.confirm(reason, promoteToRunning)
    }

    internal fun pendingExecutionErrorExitSessions(): MutableSet<String> {
        return pendingController.pendingExecutionErrorExitSessions()
    }

    internal fun rememberPendingExecutionErrorExit(sessionId: String) {
        pendingController.rememberPendingExecutionErrorExit(sessionId)
    }

    internal fun pendingExecutionErrorRecoveredSessions(): MutableSet<String> {
        return pendingController.pendingExecutionErrorRecoveredSessions()
    }

    internal suspend fun syncPendingExecutionErrorExitSessions(): Boolean {
        return pendingController.syncPendingExecutionErrorExitSessions()
    }

    internal suspend fun syncPendingExecutionErrorRecoveredSessions(): Boolean {
        return pendingController.syncPendingExecutionErrorRecoveredSessions()
    }

    internal fun registerTaskErrorNetworkCallback() {
        networkRetryController.register()
    }

    internal fun unregisterTaskErrorNetworkCallback() {
        networkRetryController.unregister()
    }
}
