package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.flow.update

internal class AssistantSessionClarificationStepHandler(
    private val viewModel: AssistantViewModel
) {
    fun appendClarificationStep(
        role: VoiceRole,
        text: String,
        isUserActionEcho: Boolean = false,
    ) {
        val normalized = text.trim()
        if (normalized.isBlank()) {
            return
        }
        viewModel.internalUiState.update { state ->
            val last = state.clarificationSteps.lastOrNull()
            if (last != null &&
                last.role == role &&
                last.text == normalized &&
                last.isUserActionEcho == isUserActionEcho
            ) {
                state
            } else {
                state.copy(
                    clarificationSteps = state.clarificationSteps + ClarificationStep(
                        role = role,
                        text = normalized,
                        status = "",
                        isUserActionEcho = isUserActionEcho,
                    )
                )
            }
        }
        AppFileLogger.logConversation(
            direction = when (role) {
                VoiceRole.User -> "user"
                VoiceRole.Assistant -> "assistant"
            },
            source = "clarification_step",
            message = normalized,
            sessionId = viewModel.agentSessionId,
            taskId = viewModel.internalUiState.value.taskId
        )
    }

    fun snapshotVisibleClarificationSteps(state: Index9AssistantUiState): List<ClarificationStep> {
        val steps = state.clarificationSteps.toMutableList()
        state.liveUserTranscript
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?.let {
                AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing(
                    steps,
                    VoiceRole.User,
                    it
                )
            }
        state.liveAssistantTranscript
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?.let {
                AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing(
                    steps,
                    VoiceRole.Assistant,
                    it
                )
            }
        return steps
    }

    fun commitVisibleAssistantTranscriptIfNeeded() {
        val normalized = viewModel.internalUiState.value.liveAssistantTranscript?.trim().orEmpty()
        if (normalized.isBlank() || normalized == viewModel.lastCommittedAssistantTranscript) {
            return
        }
        viewModel.lastCommittedAssistantTranscript = normalized
        appendClarificationStep(VoiceRole.Assistant, normalized)
    }
}
