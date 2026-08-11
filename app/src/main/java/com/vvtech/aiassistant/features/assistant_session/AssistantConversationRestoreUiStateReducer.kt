package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_agent.AgentStreamCallTranscriptPolicy
import com.vvtech.aiassistant.features.assistant_tasks.callResultStatusText
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToCallPageDataAdapter
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToClarificationStepsAdapter

internal object AssistantConversationRestoreUiStateReducer {
    fun reduceForegroundResumeState(
        state: Index9AssistantUiState,
        listeningStatus: String,
        restoredStatus: String
    ): Index9AssistantUiState {
        return state.copy(
            voiceBackgroundPaused = false,
            voiceManuallyPaused = false,
            status = when {
                state.apiTtsPlaying || state.localTtsSpeaking -> listeningStatus
                state.clarificationSteps.isNotEmpty() -> restoredStatus
                else -> state.status
            }
        )
    }

    fun reduceVoiceRecoveryLoadFailureState(
        state: Index9AssistantUiState,
        tapMicToContinueStatus: String
    ): Index9AssistantUiState {
        return state.copy(
            loading = false,
            voiceConnecting = false,
            listening = false,
            processingTurn = false,
            error = null,
            status = if (state.clarificationSteps.isNotEmpty()) {
                tapMicToContinueStatus
            } else {
                state.status
            }
        )
    }

    fun reduceRestoredConversationState(
        state: Index9AssistantUiState,
        snapshot: AssistantConversationRestoreSnapshot,
        restoredStatus: String,
        idleStatus: String
    ): Index9AssistantUiState {
        val timelineItems = snapshot.timeline.timelineItems
        val restoredSteps = timelineItems
            .takeIf { it.isNotEmpty() }
            ?.let(ConversationTimelineToClarificationStepsAdapter::adapt)
            ?: restoreStepsToClarificationSteps(snapshot.steps)
        val restoreStepHasCallResult = timelineItems.any {
            it.payload is ConversationTimelinePayload.SingleCallReceipt
        } || snapshot.steps.any { it.callResult != null }
        val restoredCallPageData = restoreCallPageData(state, snapshot)
        return state.copy(
            stage = if (restoredSteps.isNotEmpty()) AssistantStage.Clarifying else AssistantStage.Idle,
            clarificationSteps = restoredSteps,
            voiceConnecting = false,
            voiceActive = false,
            listening = false,
            processingTurn = false,
            voiceManuallyPaused = false,
            voiceBackgroundPaused = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            apiAsrListening = false,
            apiAsrPartialText = null,
            apiTtsPlaying = false,
            localTtsSpeaking = false,
            error = null,
            taskId = snapshot.sessionId,
            taskStatus = snapshot.resolvedStatus,
            conversationContinuable = snapshot.conversationContinuable,
            pendingToolRestorable = snapshot.canRestorePending,
            executionStatus = restoredExecutionStatus(snapshot),
            unresolvedTaskErrorStatus = null,
            taskErrorRecoveryInProgress = false,
            timelineItems = timelineItems,
            status = when {
                snapshot.steps.isNotEmpty() -> restoredStatus
                snapshot.readOnly -> restoredStatus
                else -> idleStatus
            },
            agentPendingToolCallId = snapshot.pendingToolCallId,
            agentQuestions = snapshot.agentQuestions,
            agentCallSpec = snapshot.agentCallSpec,
            agentOptions = null,
            agentPermissionRequest = null,
            agentDocumentRequest = null,
            agentDocumentImporting = false,
            callPageData = restoredCallPageData,
            agentCallResult = snapshot.callResult.takeUnless { restoreStepHasCallResult }
        )
    }

    fun reduceRestoreFailureState(
        state: Index9AssistantUiState,
        failureStatus: String
    ): Index9AssistantUiState {
        return state.copy(
            stage = AssistantStage.Clarifying,
            clarificationSteps = emptyList(),
            status = failureStatus
        )
    }

    fun reduceVoiceRecoverySnapshotState(
        state: Index9AssistantUiState,
        snapshot: AssistantConversationRestoreSnapshot,
        restoredStatus: String
    ): Index9AssistantUiState {
        val timelineItems = snapshot.timeline.timelineItems
        val steps = timelineItems
            .takeIf { it.isNotEmpty() }
            ?.let(ConversationTimelineToClarificationStepsAdapter::adapt)
            ?: snapshot.steps
                .takeIf { it.isNotEmpty() }
                ?.let(::restoreStepsToClarificationSteps)
            ?: state.clarificationSteps
        val restoreStepHasCallResult = timelineItems.any {
            it.payload is ConversationTimelinePayload.SingleCallReceipt
        } || snapshot.steps.any { it.callResult != null }
        val restoredCallPageData = restoreCallPageData(state, snapshot)
        return state.copy(
            stage = if (steps.isNotEmpty()) AssistantStage.Clarifying else state.stage,
            clarificationSteps = steps,
            status = when {
                steps.isNotEmpty() -> restoredStatus
                snapshot.readOnly -> restoredStatus
                else -> state.status
            },
            loading = false,
            voiceConnecting = false,
            voiceActive = false,
            listening = false,
            processingTurn = false,
            voiceManuallyPaused = false,
            voiceBackgroundPaused = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            apiAsrListening = false,
            apiAsrPartialText = null,
            apiTtsPlaying = false,
            localTtsSpeaking = false,
            error = null,
            taskId = snapshot.sessionId,
            taskStatus = snapshot.resolvedStatus,
            conversationContinuable = snapshot.conversationContinuable,
            pendingToolRestorable = snapshot.canRestorePending,
            executionStatus = restoredExecutionStatus(snapshot),
            unresolvedTaskErrorStatus = null,
            taskErrorRecoveryInProgress = false,
            timelineItems = if (timelineItems.isEmpty()) state.timelineItems else timelineItems,
            agentPendingToolCallId = snapshot.pendingToolCallId,
            agentQuestions = snapshot.agentQuestions,
            agentCallSpec = snapshot.agentCallSpec,
            agentOptions = null,
            agentPermissionRequest = null,
            agentDocumentRequest = null,
            agentDocumentImporting = false,
            callPageData = restoredCallPageData,
            agentCallResult = snapshot.callResult.takeUnless { restoreStepHasCallResult }
        )
    }

    private fun restoredExecutionStatus(snapshot: AssistantConversationRestoreSnapshot): String {
        return if (snapshot.canRestorePending) "WAITING_FOR_TOOL" else "IDLE"
    }

    private fun restoreCallPageData(
        state: Index9AssistantUiState,
        snapshot: AssistantConversationRestoreSnapshot
    ): CallPageData {
        snapshot.timeline.timelineItems.takeIf { it.isNotEmpty() }?.let { timelineItems ->
            return ConversationTimelineToCallPageDataAdapter.adaptLatestSingleReceipt(
                items = timelineItems,
                fallback = state.callPageData
            )
        }
        val result = snapshot.callResult
            ?: snapshot.steps.mapNotNull { it.callResult }.singleOrNull()
            ?: return state.callPageData
        val current = state.callPageData.copy(
            name = restoredCallPageName(state.callPageData.name, snapshot, result)
        )
        return AgentStreamCallTranscriptPolicy.callResultPageData(
            current = current,
            response = AgentChatResponse(
                sessionId = snapshot.sessionId,
                type = "CALL_RESULT",
                text = null,
                callResult = result
            ),
            resultStatusText = callResultStatusText(result, snapshot.sceneType)
        )
    }

    private fun restoredCallPageName(
        currentName: String,
        snapshot: AssistantConversationRestoreSnapshot,
        result: CallResultPayload
    ): String {
        val metadataTarget = result.metadata?.get("targetName")?.trim().orEmpty()
        val normalizedCurrent = currentName.replace("\\s+".toRegex(), "").lowercase()
        return when {
            metadataTarget.isNotBlank() -> metadataTarget
            currentName.isNotBlank() && normalizedCurrent !in setOf("ai助理", "ai外呼", "chaken.ai", "chakenai") ->
                currentName
            snapshot.title.isNotBlank() -> snapshot.title
            else -> currentName
        }
    }
}

internal fun restoreStepsToClarificationSteps(
    steps: List<AssistantSessionResumeStep>
): List<ClarificationStep> {
    return steps.map { it.toClarificationStep() }
}

private fun AssistantSessionResumeStep.toClarificationStep(): ClarificationStep {
    return ClarificationStep(
        role = when (role) {
            AssistantSessionResumeRole.Assistant -> VoiceRole.Assistant
            AssistantSessionResumeRole.User -> VoiceRole.User
        },
        text = text,
        status = status,
        callResult = callResult,
        batchCallResult = batchCallResult
    )
}
