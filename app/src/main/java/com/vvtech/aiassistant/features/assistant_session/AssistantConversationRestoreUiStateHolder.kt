package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class AssistantConversationRestoreUiStateHolder(
    private val uiState: MutableStateFlow<Index9AssistantUiState>
) {
    fun applyRestoredConversation(
        snapshot: AssistantConversationRestoreSnapshot,
        restoredStatus: String,
        idleStatus: String
    ) {
        uiState.update {
            AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState(
                state = it,
                snapshot = snapshot,
                restoredStatus = restoredStatus,
                idleStatus = idleStatus
            )
        }
    }

    fun applyVoiceRecoverySnapshot(
        snapshot: AssistantConversationRestoreSnapshot,
        restoredStatus: String
    ) {
        uiState.update { current ->
            AssistantConversationRestoreUiStateReducer.reduceVoiceRecoverySnapshotState(
                state = current,
                snapshot = snapshot,
                restoredStatus = restoredStatus
            )
        }
    }

    fun applyForegroundResume(
        listeningStatus: String,
        restoredStatus: String
    ) {
        uiState.update {
            AssistantConversationRestoreUiStateReducer.reduceForegroundResumeState(
                state = it,
                listeningStatus = listeningStatus,
                restoredStatus = restoredStatus
            )
        }
    }

    fun applyVoiceRecoveryLoadFailure(tapMicToContinueStatus: String) {
        uiState.update {
            AssistantConversationRestoreUiStateReducer.reduceVoiceRecoveryLoadFailureState(
                state = it,
                tapMicToContinueStatus = tapMicToContinueStatus
            )
        }
    }

    fun applyRestoreFailure(failureStatus: String) {
        uiState.update {
            AssistantConversationRestoreUiStateReducer.reduceRestoreFailureState(
                state = it,
                failureStatus = failureStatus
            )
        }
    }
}
