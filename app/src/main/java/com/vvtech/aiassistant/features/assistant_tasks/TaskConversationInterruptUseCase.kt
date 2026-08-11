package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.data.repository.AssistantRepository

internal data class TaskConversationInterruptResult(
    val status: String,
    val fallbackStatus: String
)

internal class TaskConversationInterruptUseCase(
    private val repository: AssistantRepository
) {
    fun fallbackStatus(reason: String): String {
        return if (reason.equals(ResetTaskFlowReason, ignoreCase = true)) {
            "RUNNING"
        } else {
            "USER_INTERRUPTED"
        }
    }

    suspend fun interrupt(
        sessionId: String,
        accountId: String,
        reason: String
    ): TaskConversationInterruptResult {
        val response = repository.interruptConversation(
            sessionId = sessionId,
            userId = accountId,
            reason = reason
        )
        return TaskConversationInterruptResult(
            status = response.status,
            fallbackStatus = fallbackStatus(reason)
        )
    }

    private companion object {
        private const val ResetTaskFlowReason = "reset_task_flow"
    }
}
