package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SummaryData

internal object AssistantSessionApplyStateReducer {
    data class SessionIdentity(
        val taskId: String,
        val sceneType: String,
        val taskStatus: String
    )

    data class ApplyContent(
        val steps: List<ClarificationStep>,
        val selectionSheet: SelectionSheetData?,
        val summary: SummaryData?,
        val confirmLabel: String
    )

    data class ApplyStatusText(
        val taskReadyStatus: String,
        val selectionStatus: String?,
        val continuingStatus: String,
        val idleStatus: String
    )

    data class TextContext(
        val identity: SessionIdentity,
        val content: ApplyContent,
        val statusText: ApplyStatusText
    )

    data class VoiceContext(
        val identity: SessionIdentity,
        val content: ApplyContent,
        val statusText: ApplyStatusText,
        val realtime: VoiceRealtimeOptions
    )

    data class VoiceRealtimeOptions(
        val preserveRealtimeUi: Boolean,
        val keepRealtimeDialog: Boolean,
        val shouldDeferLatestAssistantPromptForVoice: Boolean,
        val newestBackendAssistantPrompt: String?
    )

    fun reduceTextApplyState(
        state: Index9AssistantUiState,
        context: TextContext
    ): Index9AssistantUiState {
        val content = context.content
        val statusText = context.statusText
        return state.copy(
            taskId = context.identity.taskId,
            sceneType = context.identity.sceneType,
            taskStatus = context.identity.taskStatus,
            stage = when {
                content.summary != null -> AssistantStage.Recognized
                content.selectionSheet != null -> AssistantStage.Clarifying
                content.steps.isNotEmpty() -> AssistantStage.Clarifying
                else -> AssistantStage.Idle
            },
            status = when {
                content.summary != null -> statusText.taskReadyStatus
                content.selectionSheet != null -> statusText.selectionStatus ?: statusText.idleStatus
                content.steps.isNotEmpty() -> statusText.continuingStatus
                else -> statusText.idleStatus
            },
            clarificationSteps = content.steps,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            selectionSheet = content.selectionSheet,
            summary = content.summary,
            detailSupplement = null,
            confirmLabel = content.confirmLabel,
            loading = false,
            processingTurn = false,
            error = null
        )
    }

    fun reduceVoiceApplyState(
        state: Index9AssistantUiState,
        context: VoiceContext
    ): Index9AssistantUiState {
        val content = context.content
        val statusText = context.statusText
        val realtime = context.realtime
        val hasVisibleConversation = content.steps.isNotEmpty() ||
            !state.liveUserTranscript.isNullOrBlank() ||
            !state.liveAssistantTranscript.isNullOrBlank()
        val preserveTurn = realtime.preserveRealtimeUi || realtime.keepRealtimeDialog
        return state.copy(
            taskId = context.identity.taskId,
            sceneType = context.identity.sceneType,
            taskStatus = context.identity.taskStatus,
            stage = when {
                content.summary != null -> AssistantStage.Recognized
                content.selectionSheet != null -> AssistantStage.Clarifying
                hasVisibleConversation -> AssistantStage.Clarifying
                else -> AssistantStage.Idle
            },
            status = when {
                realtime.preserveRealtimeUi -> state.status
                content.summary != null -> statusText.taskReadyStatus
                content.selectionSheet != null -> statusText.selectionStatus ?: statusText.idleStatus
                content.steps.isNotEmpty() -> statusText.continuingStatus
                else -> statusText.idleStatus
            },
            clarificationSteps = content.steps,
            liveUserTranscript = if (realtime.preserveRealtimeUi) state.liveUserTranscript else null,
            liveAssistantTranscript = when {
                realtime.preserveRealtimeUi -> state.liveAssistantTranscript
                realtime.shouldDeferLatestAssistantPromptForVoice -> realtime.newestBackendAssistantPrompt
                else -> null
            },
            selectionSheet = content.selectionSheet,
            summary = content.summary,
            detailSupplement = null,
            confirmLabel = content.confirmLabel,
            loading = false,
            processingTurn = if (preserveTurn) state.processingTurn else false,
            listening = if (preserveTurn) state.listening else false,
            error = null
        )
    }
}
