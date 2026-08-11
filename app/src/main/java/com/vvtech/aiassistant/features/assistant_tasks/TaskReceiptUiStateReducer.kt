package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole

internal object TaskReceiptUiStateReducer {

    fun applyCallResultStatus(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            callPageData = state.callPageData.copy(
                status = statusText
            ),
            processingTurn = false,
            loading = false
        )
    }

    fun appendCallNote(
        state: Index9AssistantUiState,
        note: String
    ): Index9AssistantUiState {
        return state.copy(
            callPageData = state.callPageData.copy(
                transcript = state.callPageData.transcript + TranscriptLine(
                    role = TranscriptRole.Note,
                    text = note
                )
            )
        )
    }

    fun applyCallOutcomePendingDisplay(
        state: Index9AssistantUiState,
        pendingText: String
    ): Index9AssistantUiState {
        return state.copy(
            stage = AssistantStage.Recognized,
            status = pendingText,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            loading = false,
            voiceConnecting = false,
            voiceActive = false,
            voiceManuallyPaused = false,
            listening = false,
            processingTurn = true,
            error = null,
            showAiCallPage = false,
            handoffInFlight = false,
            currentCallId = null,
            callUiMode = CallUiMode.Ai,
            callPageData = state.callPageData.copy(status = pendingText)
        )
    }

    fun applyCallSessionNonTerminalDisplay(
        state: Index9AssistantUiState,
        response: CallSessionStatusResponse,
        facts: TaskCallSessionStatusFacts,
        rebuiltTranscript: List<TranscriptLine>
    ): Index9AssistantUiState {
        val note = facts.note
        return state.copy(
            currentCallId = response.callId.ifBlank { state.currentCallId },
            callUiMode = if (facts.humanMode) {
                CallUiMode.Human
            } else {
                CallUiMode.Ai
            },
            handoffInFlight = false,
            callPageData = state.callPageData.copy(
                name = response.targetName.ifBlank { state.callPageData.name },
                sub = response.phoneNumber.ifBlank { state.callPageData.sub },
                status = response.statusMessage.ifBlank { state.callPageData.status },
                callState = response.callState,
                transcript = if (note == null) {
                    rebuiltTranscript
                } else {
                    rebuiltTranscript + TranscriptLine(TranscriptRole.Note, note)
                }
            )
        )
    }

    fun applyCallSessionTerminalDisplay(
        state: Index9AssistantUiState,
        plan: CallSessionTerminalDisplayPlan
    ): Index9AssistantUiState {
        return state.copy(
            stage = AssistantStage.Recognized,
            taskStatus = plan.taskStatus,
            status = plan.statusText,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            loading = false,
            voiceConnecting = false,
            voiceActive = false,
            voiceManuallyPaused = false,
            listening = false,
            processingTurn = false,
            error = null,
            showAiCallPage = false,
            handoffInFlight = false,
            currentCallId = null,
            callUiMode = CallUiMode.Ai,
            callPageData = state.callPageData.copy(status = plan.statusText)
        )
    }
}
