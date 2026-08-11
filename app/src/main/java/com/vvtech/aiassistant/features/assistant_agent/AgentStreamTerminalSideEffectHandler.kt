package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal data class AgentStreamTerminalSideEffectInput(
    val plan: AgentStreamTerminalResponsePlan,
    val clearPrimarySummaryAction: Boolean
)

internal class AgentStreamTerminalSideEffectHandler(
    private val clearPrimarySummaryAction: () -> Unit,
    private val clearPendingAiCallLaunch: () -> Unit,
    private val stopCallSessionPolling: () -> Unit,
    private val stopApiListening: () -> Unit,
    private val applyUiState: (Index9AssistantUiState) -> Unit,
    private val conversationListProvider: () -> List<ConversationListItem>,
    private val setConversationList: (List<ConversationListItem>) -> Unit,
    private val loadConversations: () -> Unit
) {
    fun apply(input: AgentStreamTerminalSideEffectInput) {
        val before = input.plan.nextState
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.CALL,
                eventType = "CALL_RESULT_SIDE_EFFECT_STARTED",
                sessionId = input.plan.conversationSessionId,
                taskId = before.taskId,
                callId = before.currentCallId,
                stateBefore = "terminal_plan_ready",
                stateAfter = "applying",
                result = input.plan.conversationStatus,
                reason = "agent_terminal_response"
            )
        )
        if (input.clearPrimarySummaryAction) {
            clearPrimarySummaryAction()
        }
        clearPendingAiCallLaunch()
        stopCallSessionPolling()
        stopApiListening()
        applyUiState(input.plan.nextState)
        updateConversationStatus(input.plan)
        loadConversations()
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.CALL,
                eventType = "CALL_RESULT_SIDE_EFFECT_COMPLETED",
                sessionId = input.plan.conversationSessionId,
                taskId = input.plan.nextState.taskId,
                stateBefore = "applying",
                stateAfter = "completed",
                result = input.plan.conversationStatus,
                reason = "conversation_reload_requested"
            )
        )
    }

    private fun updateConversationStatus(plan: AgentStreamTerminalResponsePlan) {
        val sessionId = plan.conversationSessionId?.takeIf { it.isNotBlank() } ?: return
        setConversationList(
            conversationListProvider().map { item ->
                if (item.sessionId == sessionId) {
                    item.copy(status = plan.conversationStatus)
                } else {
                    item
                }
            }
        )
    }
}
