package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.CoroutineScope

internal data class AssistantTaskConversationLifecycleDeps(
    val conversationListLoadUseCase: TaskConversationListLoadUseCase,
    val conversationInterruptUseCase: TaskConversationInterruptUseCase,
    val scope: CoroutineScope,
    val stateAccess: AssistantTaskConversationLifecycleStateAccess,
    val accountIdProvider: () -> String
)

internal data class AssistantTaskConversationLifecycleCallbacks(
    val stopVoiceInteraction: (String) -> Unit,
    val resetToIdleHome: () -> Unit,
    val refreshHistory: () -> Unit,
    val agentSessionId: () -> String?,
    val updateCurrentConversationCardBeforeExit: (String?, Index9AssistantUiState) -> Unit,
    val rememberPendingExecutionErrorExit: (String) -> Unit,
    val pendingExecutionErrorExitSessions: () -> Set<String>,
    val pendingExecutionErrorRecoveredSessions: () -> Set<String>,
    val syncPendingExecutionErrorExitSessions: suspend () -> Boolean,
    val syncPendingExecutionErrorRecoveredSessions: suspend () -> Boolean
)

internal class AssistantTaskConversationLifecycleHandler(
    private val deps: AssistantTaskConversationLifecycleDeps,
    private val callbacks: AssistantTaskConversationLifecycleCallbacks
) {
    private val listLoadController = TaskConversationListLoadController(
        deps = TaskConversationListLoadControllerDeps(
            scope = deps.scope,
            stateHolder = deps.stateAccess.listLoadStateHolder,
            accountIdProvider = deps.accountIdProvider,
            load = deps.conversationListLoadUseCase::load
        ),
        callbacks = TaskConversationListLoadControllerCallbacks(
            pendingExecutionErrorExitSessions = callbacks.pendingExecutionErrorExitSessions,
            pendingExecutionErrorRecoveredSessions = callbacks.pendingExecutionErrorRecoveredSessions,
            syncPendingExecutionErrorExitSessions = callbacks.syncPendingExecutionErrorExitSessions,
            syncPendingExecutionErrorRecoveredSessions = callbacks.syncPendingExecutionErrorRecoveredSessions
        )
    )

    private val interruptController = TaskConversationInterruptController(
        deps = TaskConversationInterruptControllerDeps(
            scope = deps.scope,
            taskRestoreStateHolder = deps.stateAccess.taskRestoreStateHolder,
            accountIdProvider = deps.accountIdProvider,
            fallbackStatus = deps.conversationInterruptUseCase::fallbackStatus,
            interrupt = deps.conversationInterruptUseCase::interrupt
        ),
        callbacks = TaskConversationInterruptControllerCallbacks(
            stopVoiceInteraction = callbacks.stopVoiceInteraction,
            resetToIdleHome = callbacks.resetToIdleHome,
            agentSessionId = callbacks.agentSessionId
        ),
        loadConversations = { loadConversations() }
    )

    private val exitResetController = TaskConversationExitResetController(
        deps = TaskConversationExitResetDeps(
            scope = deps.scope,
            stateReader = deps.stateAccess.exitResetStateReader,
            taskRestoreStateHolder = deps.stateAccess.taskRestoreStateHolder
        ),
        callbacks = TaskConversationExitResetCallbacks(
            stopVoiceInteraction = callbacks.stopVoiceInteraction,
            resetToIdleHome = callbacks.resetToIdleHome,
            agentSessionId = callbacks.agentSessionId,
            updateCurrentConversationCardBeforeExit = callbacks.updateCurrentConversationCardBeforeExit,
            rememberPendingExecutionErrorExit = callbacks.rememberPendingExecutionErrorExit,
            syncPendingExecutionErrorExitSessions = callbacks.syncPendingExecutionErrorExitSessions
        ),
        loadConversations = ::loadConversations
    )

    fun resetForNewEntry(reason: String = "stop_voice_interaction") {
        callbacks.stopVoiceInteraction(reason)
        callbacks.resetToIdleHome()
    }

    fun interruptForUserClose(reason: String = "user_close") {
        interruptController.interruptForUserClose(reason)
    }

    fun pauseForBackground() {
        callbacks.stopVoiceInteraction("background_pause")
        deps.stateAccess.backgroundPauseStateHolder.applyBackgroundPause()
    }

    fun pauseAndResetLocalUi(
        reason: String = "navigate_back_pause",
        reloadConversations: Boolean = true
    ) {
        exitResetController.pauseAndResetLocalUi(reason, reloadConversations)
    }

    @Suppress("UNUSED_PARAMETER")
    fun loadConversations(reason: String = "default") {
        listLoadController.loadConversations(reason)
    }

    fun returnToHomeFromResultPage() {
        callbacks.stopVoiceInteraction("stop_voice_interaction")
        callbacks.resetToIdleHome()
        callbacks.refreshHistory()
    }
}
