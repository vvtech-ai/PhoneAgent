package com.vvtech.aiassistant.features.assistant_shell

internal data class AssistantRootAuthResetSessionCallbackDeps(
    val activeAccountIdProvider: () -> String,
    val log: (String) -> Unit,
    val onResetTaskConversationForNewEntry: (String) -> Unit,
    val onResetTranslationRuntime: (String) -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onClearPendingVoiceEntryState: () -> Unit,
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

internal fun buildAssistantRootAuthResetSessionCallback(
    deps: AssistantRootAuthResetSessionCallbackDeps
): (String) -> Unit {
    return { reason ->
        resetAssistantSessionScopedUiState(
            reason = reason,
            activeAccountId = deps.activeAccountIdProvider(),
            log = AssistantSessionScopedResetLogCallbacks { input ->
                deps.log(
                    "reset session scoped ui reason=${input.reason} " +
                        "activeAccountId=${input.activeAccountId}"
                )
            },
            primary = AssistantSessionScopedPrimaryResetCallbacks(
                onResetTaskConversationForNewEntry = deps.onResetTaskConversationForNewEntry,
                onResetTranslationRuntime = deps.onResetTranslationRuntime,
                onClearLocalTaskItemsForRequirementEntry =
                    deps.onClearLocalTaskItemsForRequirementEntry,
                onClearPendingVoiceEntryState = deps.onClearPendingVoiceEntryState
            ),
            ui = AssistantSessionScopedUiResetCallbacks(
                onClearAgentRequests = deps.onClearAgentRequests,
                onClearRequestedPermission = deps.onClearRequestedPermission,
                onClearSystemPhonePending = deps.onClearSystemPhonePending,
                onClearIdentityOverlayError = deps.onClearIdentityOverlayError,
                onSetIdentityInitOverlayVisible = deps.onSetIdentityInitOverlayVisible,
                onDismissNetworkBlocker = deps.onDismissNetworkBlocker,
                onHideDialSheet = deps.onHideDialSheet,
                onClearSessionScopedUiFlags = deps.onClearSessionScopedUiFlags,
                onHideVoiceModelSheet = deps.onHideVoiceModelSheet,
                onCloseHomeComposer = deps.onCloseHomeComposer,
                onGoHome = deps.onGoHome
            )
        )
    }
}
