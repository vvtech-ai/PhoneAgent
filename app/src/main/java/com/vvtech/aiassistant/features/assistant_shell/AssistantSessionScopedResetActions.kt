package com.vvtech.aiassistant.features.assistant_shell

internal data class AssistantSessionScopedResetLogInput(
    val reason: String,
    val activeAccountId: String
)

internal class AssistantSessionScopedResetLogCallbacks(
    val onLogReset: (AssistantSessionScopedResetLogInput) -> Unit
)

internal class AssistantSessionScopedPrimaryResetCallbacks(
    val onResetTaskConversationForNewEntry: (String) -> Unit,
    val onResetTranslationRuntime: (String) -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onClearPendingVoiceEntryState: () -> Unit
)

internal class AssistantSessionScopedUiResetCallbacks(
    val onClearAgentRequests: () -> Unit,
    val onClearRequestedPermission: () -> Unit,
    val onClearSystemPhonePending: () -> Unit,
    val onClearIdentityOverlayError: () -> Unit,
    val onSetIdentityInitOverlayVisible: (Boolean) -> Unit,
    val onDismissNetworkBlocker: () -> Unit,
    val onHideDialSheet: () -> Unit,
    val onClearSessionScopedUiFlags: () -> Unit,
    val onHideVoiceModelSheet: () -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val onGoHome: () -> Unit
)

internal fun resetAssistantSessionScopedUiState(
    reason: String,
    activeAccountId: String,
    log: AssistantSessionScopedResetLogCallbacks,
    primary: AssistantSessionScopedPrimaryResetCallbacks,
    ui: AssistantSessionScopedUiResetCallbacks
) {
    log.onLogReset(
        AssistantSessionScopedResetLogInput(
            reason = reason,
            activeAccountId = activeAccountId
        )
    )
    primary.onResetTaskConversationForNewEntry("account_boundary_$reason")
    primary.onResetTranslationRuntime(reason)
    primary.onClearLocalTaskItemsForRequirementEntry()
    primary.onClearPendingVoiceEntryState()
    ui.onClearAgentRequests()
    ui.onClearRequestedPermission()
    ui.onClearSystemPhonePending()
    ui.onClearIdentityOverlayError()
    ui.onSetIdentityInitOverlayVisible(false)
    ui.onDismissNetworkBlocker()
    ui.onHideDialSheet()
    ui.onClearSessionScopedUiFlags()
    ui.onHideVoiceModelSheet()
    ui.onCloseHomeComposer()
    ui.onGoHome()
}
