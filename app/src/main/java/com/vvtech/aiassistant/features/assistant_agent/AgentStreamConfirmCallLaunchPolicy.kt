package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptRole

internal data class AgentStreamConfirmCallLaunchInput(
    val state: Index9AssistantUiState,
    val latestCallPageSeed: CallPageData,
    val sessionId: String,
    val auto: Boolean,
    val dialingStatusText: String,
    val manualEchoText: String
)

internal data class AgentStreamConfirmCallLaunchPlan(
    val callPageSeed: CallPageData,
    val nextState: Index9AssistantUiState,
    val userEchoText: String?
)

internal object AgentStreamConfirmCallLaunchPolicy {
    fun plan(input: AgentStreamConfirmCallLaunchInput): AgentStreamConfirmCallLaunchPlan {
        val callSeed = input.latestCallPageSeed.copy(
            status = input.dialingStatusText,
            transcript = AgentStreamCallTranscriptPolicy.mergeDistinctTranscript(
                input.latestCallPageSeed.transcript.filter { it.role == TranscriptRole.Note },
                input.state.agentCallSpec
                    ?.let { AgentStreamCallTranscriptPolicy.callSpecTranscriptNotes(it) }
                    .orEmpty()
            )
        )
        return AgentStreamConfirmCallLaunchPlan(
            callPageSeed = callSeed,
            nextState = input.state.copy(
                stage = AssistantStage.Recognized,
                processingTurn = true,
                error = null,
                status = input.dialingStatusText,
                taskId = input.sessionId,
                callUiMode = CallUiMode.Ai,
                callPageData = callSeed,
                showAiCallPage = true,
                handoffInFlight = false,
                agentCallSpec = null,
                agentCallResult = null
            ),
            userEchoText = input.manualEchoText.takeUnless { input.auto }
        )
    }
}
