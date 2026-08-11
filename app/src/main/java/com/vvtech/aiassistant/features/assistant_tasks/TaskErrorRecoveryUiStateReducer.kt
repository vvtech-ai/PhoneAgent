package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.domain.task.isRecoverableTaskExecutionErrorStatus
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal const val TaskCallNetworkReconnectingStatus = "网络异常，AI 通话仍在后台继续，正在重连..."

internal data class TaskErrorRecoveryConfirmedPlan(
    val shouldApply: Boolean,
    val recoveredStatus: String,
    val recoverableStatus: Boolean
)

internal object TaskErrorRecoveryUiStateReducer {
    fun markRecoveryInProgress(
        state: Index9AssistantUiState,
        status: String
    ): Index9AssistantUiState {
        return state.copy(
            unresolvedTaskErrorStatus = status,
            taskErrorRecoveryInProgress = true
        )
    }

    fun applyNetworkTaskErrorState(
        state: Index9AssistantUiState,
        keepCallContext: Boolean,
        message: String
    ): Index9AssistantUiState {
        return if (keepCallContext) {
            state.copy(
                showAiCallPage = true,
                error = message,
                status = message,
                loading = false,
                callPageData = state.callPageData.copy(
                    status = message
                ),
                voiceConnecting = false,
                listening = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                liveUserTranscript = null
            )
        } else {
            state.copy(
                taskStatus = "NETWORK_ERROR",
                unresolvedTaskErrorStatus = "NETWORK_ERROR",
                taskErrorRecoveryInProgress = false,
                voiceManuallyPaused = true,
                voiceBackgroundPaused = false,
                voiceActive = true,
                voiceConnecting = false,
                listening = false,
                processingTurn = false,
                loading = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                liveUserTranscript = null,
                error = message,
                status = message
            )
        }
    }

    fun confirmedRecoveryPlan(
        state: Index9AssistantUiState,
        promoteToRunning: Boolean
    ): TaskErrorRecoveryConfirmedPlan {
        val recoverableStatus = promoteToRunning && (
            isRecoverableTaskExecutionErrorStatus(state.taskStatus) ||
                state.unresolvedTaskErrorStatus
                    ?.let(::isRecoverableTaskExecutionErrorStatus)
                    ?: false
            )
        return TaskErrorRecoveryConfirmedPlan(
            shouldApply = !state.unresolvedTaskErrorStatus.isNullOrBlank() ||
                state.taskErrorRecoveryInProgress ||
                recoverableStatus,
            recoveredStatus = if (recoverableStatus) "RUNNING" else state.taskStatus,
            recoverableStatus = recoverableStatus
        )
    }

    fun applyConfirmedRecovery(
        state: Index9AssistantUiState,
        plan: TaskErrorRecoveryConfirmedPlan
    ): Index9AssistantUiState {
        return state.copy(
            taskStatus = plan.recoveredStatus,
            unresolvedTaskErrorStatus = null,
            taskErrorRecoveryInProgress = false
        )
    }
}
