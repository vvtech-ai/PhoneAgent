package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.model.UserContextPayload

internal class AgentStreamCallResultRuntimeHandler(
    private val isVoiceMode: () -> Boolean
) {
    fun logAgentContext(action: String, sessionId: String, context: UserContextPayload) {
        AppFileLogger.i(
            "AGENT_CONTEXT_DIAG",
            AgentStreamCallResultHistoryPolicy.agentContextLogMessage(
                action = action,
                sessionId = sessionId,
                voice = isVoiceMode(),
                context = context
            )
        )
    }

    fun logApplyCallResult(input: AgentStreamApplyCallResultLogInput) {
        logApplyCallResult(
            responseSessionId = input.responseSessionId,
            currentSessionId = input.currentSessionId,
            callResult = input.callResult,
            resolvedConversationStatus = input.resolvedConversationStatus,
            resultStatusText = input.resultStatusText
        )
    }

    fun logApplyCallResult(
        responseSessionId: String,
        currentSessionId: String?,
        callResult: CallResultPayload?,
        resolvedConversationStatus: String,
        resultStatusText: String
    ) {
        AppFileLogger.i(
            "ReportCallOutcome",
            AgentStreamCallResultHistoryPolicy.applyCallResultLogMessage(
                responseSessionId = responseSessionId,
                currentSessionId = currentSessionId,
                callResult = callResult,
                resolvedConversationStatus = resolvedConversationStatus,
                resultStatusText = resultStatusText
            )
        )
    }
}
