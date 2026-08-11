package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class TaskConversationInterruptControllerDeps(
    val scope: CoroutineScope,
    val taskRestoreStateHolder: TaskRestoreStateHolder,
    val accountIdProvider: () -> String,
    val fallbackStatus: (String) -> String,
    val interrupt: suspend (String, String, String) -> TaskConversationInterruptResult
)

internal data class TaskConversationInterruptControllerCallbacks(
    val stopVoiceInteraction: (String) -> Unit,
    val resetToIdleHome: () -> Unit,
    val agentSessionId: () -> String?
)

internal class TaskConversationInterruptController(
    private val deps: TaskConversationInterruptControllerDeps,
    private val callbacks: TaskConversationInterruptControllerCallbacks,
    private val loadConversations: () -> Unit,
    private val warn: (String) -> Unit = { message -> AppFileLogger.w("Index9VM", message) }
) {
    fun interruptForUserClose(reason: String = "user_close") {
        val sessionId = callbacks.agentSessionId()
        val fallbackStatus = deps.fallbackStatus(reason)
        callbacks.stopVoiceInteraction(reason)
        if (!sessionId.isNullOrBlank()) {
            deps.scope.launch {
                runCatching {
                    deps.interrupt(
                        sessionId,
                        deps.accountIdProvider(),
                        reason
                    )
                }.onSuccess { result ->
                    deps.taskRestoreStateHolder.updateConversationCardStatus(
                        sessionId = sessionId,
                        status = result.status
                    )
                    loadConversations()
                }.onFailure { throwable ->
                    warn("interrupt conversation failed session=$sessionId: ${throwable.message}")
                    deps.taskRestoreStateHolder.updateConversationCardStatus(
                        sessionId = sessionId,
                        status = fallbackStatus
                    )
                }
            }
        }
        callbacks.resetToIdleHome()
    }
}
