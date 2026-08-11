package com.vvtech.aiassistant.core.model

import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent

sealed interface AgentStreamEvent {
    data class TextDelta(val text: String) : AgentStreamEvent
    data class ThinkingDelta(val text: String) : AgentStreamEvent
    data class StatusDelta(
        val text: String,
        val batchId: String? = null,
        val itemIndex: Int = 0,
        val total: Int = 0,
        val targetName: String = "",
        val phoneNumber: String = "",
        val batchStatus: String? = null,
        val progressOnly: Boolean = false
    ) : AgentStreamEvent
    data class ThinkingDone(val durationMs: Long) : AgentStreamEvent
    data class ToolCallStart(
        val id: String,
        val name: String,
        val argsPartial: String
    ) : AgentStreamEvent
    data class ToolCallComplete(
        val id: String,
        val name: String,
        val args: String,
        val result: String
    ) : AgentStreamEvent
    data class ToolCard(val card: ToolCardInfo) : AgentStreamEvent
    data class Signal(val payload: AgentChatResponse) : AgentStreamEvent
    data class Final(val payload: AgentChatResponse) : AgentStreamEvent
    data class TimelineCommitted(val event: ConversationLedgerEvent) : AgentStreamEvent
    data class Err(
        val message: String,
        val errorCode: String? = null,
        val category: String? = null,
        val retryable: Boolean? = null,
        val recoveryAction: String? = null,
        val traceId: String? = null,
        val stage: String? = null
    ) : AgentStreamEvent {
        val hasStructuredFailure: Boolean
            get() = !errorCode.isNullOrBlank() || !category.isNullOrBlank()

        val isNetworkFailure: Boolean
            get() = category.equals("NETWORK", ignoreCase = true) ||
                errorCode.equals("NETWORK_TRANSPORT", ignoreCase = true)
    }
    object Done : AgentStreamEvent
    object Heartbeat : AgentStreamEvent
}
