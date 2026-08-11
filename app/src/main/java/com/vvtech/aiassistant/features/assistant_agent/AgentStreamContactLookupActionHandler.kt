package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal data class AgentStreamContactLookupActionRuntime(
    val stateProvider: () -> Index9AssistantUiState,
    val sessionIdProvider: () -> String?,
    val userIdProvider: () -> String
)

internal data class AgentStreamContactLookupActionCallbacks(
    val clearWithoutPendingTool: () -> Unit,
    val prepareSubmitting: (String) -> Unit,
    val appendAssistantPlaceholder: () -> Int
)

internal class AgentStreamContactLookupActionHandler(
    private val runtime: AgentStreamContactLookupActionRuntime,
    private val callbacks: AgentStreamContactLookupActionCallbacks,
    private val submitter: AgentStreamContactLookupResultSubmitter
) {
    fun onResult(payload: Map<String, Any?>) {
        val sessionId = runtime.sessionIdProvider() ?: return
        val pendingToolCallId = runtime.stateProvider().agentPendingToolCallId
        if (pendingToolCallId.isNullOrBlank()) {
            callbacks.clearWithoutPendingTool()
            return
        }
        callbacks.prepareSubmitting(SubmittingStatus)
        val placeholderIndex = callbacks.appendAssistantPlaceholder()
        submitter.submitContactLookupResult(
            AgentContactLookupResultSubmitRequest(
                sessionId = sessionId,
                pendingToolCallId = pendingToolCallId,
                userId = runtime.userIdProvider(),
                result = payload,
                placeholderIndex = placeholderIndex,
                failureMessage = SubmitFailureMessage
            )
        )
    }

    private companion object {
        private const val SubmittingStatus = "AI处理中"
        private const val SubmitFailureMessage = "联系人查询回传失败"
    }
}
