package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal data class AgentStreamMakeCallRequestPlan(
    val nextState: Index9AssistantUiState,
    val nextCallPageSeed: CallPageData?
)

internal object AgentStreamMakeCallRequestPolicy {
    fun plan(
        state: Index9AssistantUiState,
        currentCallPageSeed: CallPageData,
        response: AgentChatResponse
    ): AgentStreamMakeCallRequestPlan {
        val spec = response.callSpec
        val resolvedSceneType = AgentStreamCallTranscriptPolicy.resolveCallSpecSceneType(
            spec?.scene,
            state.sceneType
        )
        val nextCallPageSeed = spec?.let {
            currentCallPageSeed.copy(
                name = it.targetName.ifBlank { currentCallPageSeed.name },
                sub = it.phoneNumber.ifBlank { currentCallPageSeed.sub },
                status = "准备拨打",
                transcript = AgentStreamCallTranscriptPolicy.mergeDistinctTranscript(
                    currentCallPageSeed.transcript,
                    AgentStreamCallTranscriptPolicy.callSpecTranscriptNotes(it)
                )
            )
        }
        return AgentStreamMakeCallRequestPlan(
            nextState = state.copy(
                stage = AssistantStage.Recognized,
                processingTurn = false,
                loading = false,
                error = null,
                status = "信息确认完毕，准备拨打电话",
                sceneType = resolvedSceneType,
                agentCallSpec = response.callSpec,
                agentQuestions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = response.pendingToolCallId
            ),
            nextCallPageSeed = nextCallPageSeed
        )
    }
}
