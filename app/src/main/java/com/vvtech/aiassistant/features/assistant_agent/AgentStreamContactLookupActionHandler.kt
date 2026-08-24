package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class AgentStreamContactLookupActionRuntime(
    val stateProvider: () -> Index9AssistantUiState,
    val sessionIdProvider: () -> String?,
    val userIdProvider: () -> String,
    val languageCodeProvider: () -> String = { "zh-CN" },
    val responseLanguageProvider: () -> String = { "Simplified Chinese" }
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
        callbacks.prepareSubmitting(submittingStatus())
        val placeholderIndex = callbacks.appendAssistantPlaceholder()
        submitter.submitContactLookupResult(
            AgentContactLookupResultSubmitRequest(
                sessionId = sessionId,
                pendingToolCallId = pendingToolCallId,
                userId = runtime.userIdProvider(),
                result = payload,
                placeholderIndex = placeholderIndex,
                failureMessage = submitFailureMessage(),
                languageCode = runtime.languageCodeProvider(),
                responseLanguage = runtime.responseLanguageProvider()
            )
        )
    }

    private fun submittingStatus(): String =
        currentAppText("AI处理中", "AI is processing")

    private fun submitFailureMessage(): String =
        currentAppText("联系人查询回传失败", "Failed to return contact lookup result")
}
