package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal data class AgentStreamTerminalResponseInput(
    val state: Index9AssistantUiState,
    val response: AgentChatResponse,
    val statusText: String,
    val conversationStatus: String,
    val conversationSessionId: String?
)

internal data class AgentStreamTerminalResponsePlan(
    val nextState: Index9AssistantUiState,
    val statusText: String,
    val conversationStatus: String,
    val conversationSessionId: String?
)

internal object AgentStreamTerminalResponsePolicy {
    fun callResult(input: AgentStreamTerminalResponseInput): AgentStreamTerminalResponsePlan {
        val receiptState = AgentStreamTimelineReceiptPolicy.appendSingleReceipt(
            state = input.state,
            responseSessionId = input.conversationSessionId ?: input.response.sessionId,
            callResult = input.response.callResult,
            toolCallId = input.response.pendingToolCallId ?: input.state.agentPendingToolCallId
        )
        return AgentStreamTerminalResponsePlan(
            nextState = receiptState.copy(
                stage = AssistantStage.Recognized,
                processingTurn = false,
                loading = false,
                listening = false,
                voiceConnecting = false,
                voiceActive = false,
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                error = null,
                status = input.statusText,
                taskStatus = input.conversationStatus,
                showAiCallPage = false,
                currentCallId = null,
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                callPageData = receiptState.callPageData.copy(status = input.statusText),
                agentCallSpec = null,
                agentQuestions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = null
            ),
            statusText = input.statusText,
            conversationStatus = input.conversationStatus,
            conversationSessionId = input.conversationSessionId
        )
    }

    fun batchCallResult(
        input: AgentStreamTerminalResponseInput,
        batchAttemptId: String? = null,
    ): AgentStreamTerminalResponsePlan {
        val receiptState = AgentStreamTimelineReceiptPolicy.upsertBatchReceipt(
            state = input.state,
            responseSessionId = input.conversationSessionId ?: input.response.sessionId,
            result = input.response.batchCallResult,
            batchAttemptId = batchAttemptId
                ?: input.response.pendingToolCallId
                ?: input.state.agentPendingToolCallId,
            stepIndex = input.state.clarificationSteps.lastIndex.coerceAtLeast(0)
        )
        return AgentStreamTerminalResponsePlan(
            nextState = receiptState.copy(
                stage = AssistantStage.Recognized,
                processingTurn = false,
                loading = false,
                listening = false,
                voiceConnecting = false,
                voiceActive = false,
                voiceManuallyPaused = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                error = null,
                status = input.statusText,
                taskStatus = input.conversationStatus,
                showAiCallPage = false,
                currentCallId = null,
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                agentCallSpec = null,
                agentCallResult = null,
                agentQuestions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = null
            ),
            statusText = input.statusText,
            conversationStatus = input.conversationStatus,
            conversationSessionId = input.conversationSessionId
        )
    }
}
