package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_tasks.TaskRestoreStateHolder
import com.vvtech.aiassistant.features.assistant_tasks.normalizeConversationTaskStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow

internal class RestoreHandlerDeps(
    val restoreUseCase: AssistantConversationRestoreUseCase,
    val uiState: MutableStateFlow<Index9AssistantUiState>,
    val conversationList: MutableStateFlow<List<ConversationListItem>>,
    val taskRestoreStateHolder: TaskRestoreStateHolder,
    val scope: CoroutineScope
)

internal class RestoreCallbacks(
    val setAgentSessionId: (String) -> Unit,
    val idleStatus: () -> String,
    val localizedListeningStatus: () -> String,
    val localizedTapMicToContinueStatus: () -> String,
    val log: (String) -> Unit
)

internal class ConversationRestoreHandler(
    private val deps: RestoreHandlerDeps,
    private val callbacks: RestoreCallbacks
) {
    private val uiStateHolder = AssistantConversationRestoreUiStateHolder(deps.uiState)
    private val stateReader = AssistantConversationRestoreStateReader(deps.uiState)
    private val snapshotApplier = AssistantConversationRestoreSnapshotApplier(
        uiStateHolder = uiStateHolder,
        taskRestoreStateHolder = deps.taskRestoreStateHolder
    )
    private val snapshotLoader = AssistantConversationRestoreSnapshotLoader(
        restoreUseCase = deps.restoreUseCase,
        conversationList = deps.conversationList
    )
    private val runtimeHandler = AssistantConversationRestoreRuntimeHandler(
        deps = AssistantConversationRestoreRuntimeDeps(
            stateReader = stateReader,
            scope = deps.scope
        ),
        callbacks = callbacks,
        snapshotLoader = snapshotLoader,
        snapshotApplier = snapshotApplier
    )

    fun updateCurrentConversationCardBeforeExit(
        sessionId: String?,
        state: Index9AssistantUiState
    ) {
        if (sessionId.isNullOrBlank()) return
        val normalizedStatus = normalizeConversationTaskStatus(state.taskStatus)
        deps.taskRestoreStateHolder.updateConversationCardStatus(sessionId, normalizedStatus)
    }

    fun resumeTaskConversationForForeground() {
        runtimeHandler.resumeTaskConversationForForeground()
    }

    suspend fun syncConversationSnapshotForVoiceRecovery(
        sessionId: String,
        reason: String
    ): Boolean {
        return runtimeHandler.syncConversationSnapshotForVoiceRecovery(sessionId, reason)
    }

    fun resumeConversation(sessionId: String, onFinished: (() -> Unit)? = null) {
        runtimeHandler.resumeConversation(sessionId, onFinished)
    }
}
