package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal data class AgentStreamNormalActionSubmitInput(
    val sessionId: String,
    val actionDraft: AgentStreamActionDraft,
    val appendUserEcho: Boolean = true,
    val stateReducer: (Index9AssistantUiState) -> Index9AssistantUiState,
    val contextReason: String,
    val logAction: String,
    val failureMessage: String,
    val beforeRecover: (() -> Unit)? = null
)

internal class AgentStreamNormalActionSubmitHandler(
    private val appendUserStep: (String) -> Unit,
    private val updateUiState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    private val appendAssistantPlaceholder: () -> Int,
    private val submitAction: (AgentStreamActionSubmitRequest, (() -> Unit)?) -> Unit,
    private val channelProvider: () -> String,
    private val userIdProvider: () -> String,
    private val languageCodeProvider: () -> String,
    private val responseLanguageProvider: () -> String
) {
    fun submit(input: AgentStreamNormalActionSubmitInput) {
        if (input.appendUserEcho) {
            appendUserStep(input.actionDraft.echoText)
        }
        updateUiState(input.stateReducer)
        val placeholderIndex = appendAssistantPlaceholder()
        submitAction(
            AgentStreamActionSubmitRequest(
                sessionId = input.sessionId,
                actionId = input.actionDraft.actionId,
                actionPayload = input.actionDraft.actionPayload,
                contextReason = input.contextReason,
                logAction = input.logAction,
                channel = channelProvider(),
                userId = userIdProvider(),
                placeholderIndex = placeholderIndex,
                failureMessage = input.failureMessage,
                languageCode = languageCodeProvider(),
                responseLanguage = responseLanguageProvider()
            ),
            input.beforeRecover
        )
    }
}
