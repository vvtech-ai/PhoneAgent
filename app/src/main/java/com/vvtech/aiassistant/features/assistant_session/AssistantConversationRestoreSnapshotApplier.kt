package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant_tasks.TaskRestoreStateHolder

internal class AssistantConversationRestoreSnapshotApplier(
    private val uiStateHolder: AssistantConversationRestoreUiStateHolder,
    private val taskRestoreStateHolder: TaskRestoreStateHolder
) {
    fun applyRestoredConversation(
        snapshot: AssistantConversationRestoreSnapshot,
        restoredStatus: String,
        idleStatus: String
    ) {
        taskRestoreStateHolder.updateConversationCardStatus(
            sessionId = snapshot.sessionId,
            status = snapshot.resolvedStatus
        )
        uiStateHolder.applyRestoredConversation(
            snapshot = snapshot,
            restoredStatus = restoredStatus,
            idleStatus = idleStatus
        )
    }

    fun applyVoiceRecoverySnapshot(
        snapshot: AssistantConversationRestoreSnapshot,
        restoredStatus: String
    ) {
        taskRestoreStateHolder.updateConversationCardStatus(
            sessionId = snapshot.sessionId,
            status = snapshot.resolvedStatus
        )
        uiStateHolder.applyVoiceRecoverySnapshot(
            snapshot = snapshot,
            restoredStatus = restoredStatus
        )
    }

    fun applyForegroundResume(
        listeningStatus: String,
        restoredStatus: String
    ) {
        uiStateHolder.applyForegroundResume(
            listeningStatus = listeningStatus,
            restoredStatus = restoredStatus
        )
    }

    fun applyVoiceRecoveryLoadFailure(tapMicToContinueStatus: String) {
        uiStateHolder.applyVoiceRecoveryLoadFailure(tapMicToContinueStatus)
    }

    fun applyRestoreFailure(failureStatus: String) {
        uiStateHolder.applyRestoreFailure(failureStatus)
    }
}
