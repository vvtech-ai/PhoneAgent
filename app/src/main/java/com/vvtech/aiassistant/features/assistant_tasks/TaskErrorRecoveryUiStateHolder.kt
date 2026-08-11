package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class TaskErrorRecoveryUiStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {
    fun currentState(): Index9AssistantUiState = uiState.value

    fun markRecoveryInProgress(status: String) {
        uiState.update {
            TaskErrorRecoveryUiStateReducer.markRecoveryInProgress(
                state = it,
                status = status
            )
        }
    }

    fun applyNetworkTaskErrorState(keepCallContext: Boolean, message: String) {
        uiState.update {
            TaskErrorRecoveryUiStateReducer.applyNetworkTaskErrorState(
                state = it,
                keepCallContext = keepCallContext,
                message = message
            )
        }
    }

    fun confirmedRecoveryPlan(promoteToRunning: Boolean): TaskErrorRecoveryConfirmedPlan {
        return TaskErrorRecoveryUiStateReducer.confirmedRecoveryPlan(
            state = uiState.value,
            promoteToRunning = promoteToRunning
        )
    }

    fun applyConfirmedRecovery(plan: TaskErrorRecoveryConfirmedPlan) {
        uiState.update {
            TaskErrorRecoveryUiStateReducer.applyConfirmedRecovery(
                state = it,
                plan = plan
            )
        }
    }
}
