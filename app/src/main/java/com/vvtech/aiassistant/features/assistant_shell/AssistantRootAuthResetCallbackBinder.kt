package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.logging.AppFileLogger

internal data class AssistantRootAuthResetCallbackBindingArgs(
    val rootRuntimeGraph: AssistantRootRuntimeGraph,
    val taskEntry: AssistantTaskEntryState,
    val onResetTaskConversationForNewEntry: (String) -> Unit,
    val onSetIdentityInitOverlayVisible: (Boolean) -> Unit
)

internal fun bindAssistantRootAuthResetSessionCallback(
    args: AssistantRootAuthResetCallbackBindingArgs
) {
    val rootRuntimeGraph = args.rootRuntimeGraph
    val authRuntime = rootRuntimeGraph.runtime.auth
    val translationRuntime = rootRuntimeGraph.runtime.translation
    val contactRuntime = rootRuntimeGraph.runtime.contact
    val transientOverlayState = rootRuntimeGraph.state.transientOverlay
    val permissionOverlayState = rootRuntimeGraph.state.permissionOverlay
    val systemPhoneCallState = rootRuntimeGraph.state.systemPhoneCall
    val callDialState = rootRuntimeGraph.state.callDial
    val homeComposerState = rootRuntimeGraph.state.homeComposer
    val navigationState = rootRuntimeGraph.state.navigation
    rootRuntimeGraph.environment.authResetSessionCallback[0] =
        buildAssistantRootAuthResetSessionCallback(
            AssistantRootAuthResetSessionCallbackDeps(
                activeAccountIdProvider = { authRuntime.activeAccountId },
                log = { message -> AppFileLogger.i("AssistantRootScreen", message) },
                onResetTaskConversationForNewEntry =
                    args.onResetTaskConversationForNewEntry,
                onResetTranslationRuntime = translationRuntime::resetForAccountBoundary,
                onClearLocalTaskItemsForRequirementEntry = {
                    clearAssistantRootLocalTaskItemsForRequirementEntry(args.taskEntry)
                },
                onClearPendingVoiceEntryState = {
                    clearAssistantRootPendingVoiceEntryState(rootRuntimeGraph, args.taskEntry)
                },
                onClearAgentRequests = transientOverlayState::clearAgentRequests,
                onClearRequestedPermission = permissionOverlayState::clearRequestedPermission,
                onClearSystemPhonePending = systemPhoneCallState::clearPending,
                onClearIdentityOverlayError = { contactRuntime.identityOverlayError = null },
                onSetIdentityInitOverlayVisible = args.onSetIdentityInitOverlayVisible,
                onDismissNetworkBlocker = permissionOverlayState::dismissNetworkBlocker,
                onHideDialSheet = callDialState::hideDialSheet,
                onClearSessionScopedUiFlags = authRuntime::clearSessionScopedUiFlags,
                onHideVoiceModelSheet = transientOverlayState::hideVoiceModelSheet,
                onCloseHomeComposer = homeComposerState::close,
                onGoHome = navigationState::goHome
            )
        )
}
