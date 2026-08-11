package com.vvtech.aiassistant.features.assistant_shell

internal data class AssistantRootVoicePermissionLauncherCallbackDeps(
    val accountProvider: () -> AssistantVoicePermissionAccountState,
    val voiceEntryStateProvider: () -> AssistantVoiceEntryPermissionState,
    val voiceInteractionStateProvider: () -> AssistantVoiceInteractionPermissionState,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onPermissionDenied: () -> Unit,
    val onVoiceEntryGrantedSignal: () -> Unit,
    val onClearPendingVoiceEntryState: () -> Unit,
    val onClearPendingVoiceInteractionState: () -> Unit,
    val onToggleVoiceInput: () -> Unit,
    val onStartNewTaskEntry: () -> Unit,
    val onApiMicClick: () -> Unit,
    val log: (String) -> Unit
)

internal fun buildAssistantRootVoicePermissionLauncherCallbacks(
    deps: AssistantRootVoicePermissionLauncherCallbackDeps
): AssistantVoicePermissionLauncherCallbacks {
    return AssistantVoicePermissionLauncherCallbacks(
        accountProvider = deps.accountProvider,
        onMicrophonePermissionGrantedChange = deps.onMicrophonePermissionGrantedChange,
        onPermissionDenied = deps.onPermissionDenied,
        voiceEntry = AssistantVoiceEntryPermissionCallbacks(
            stateProvider = deps.voiceEntryStateProvider,
            onGrantedSignal = deps.onVoiceEntryGrantedSignal,
            onClearPending = deps.onClearPendingVoiceEntryState,
            onDropStale = { stale ->
                deps.log(
                    "drop stale voice entry permission result pending=${stale.pendingActive} " +
                        "pendingAccount=${stale.pendingAccountId} " +
                        "currentAccount=${stale.currentAccountId} loggedIn=${stale.mockLoggedIn}"
                )
            }
        ),
        voiceInteraction = AssistantVoiceInteractionPermissionCallbacks(
            stateProvider = deps.voiceInteractionStateProvider,
            onToggleVoiceInput = deps.onToggleVoiceInput,
            onStartNewTaskEntry = deps.onStartNewTaskEntry,
            onApiMicClick = deps.onApiMicClick,
            onClearPending = deps.onClearPendingVoiceInteractionState,
            onDropStale = { stale ->
                deps.log(
                    "drop stale voice interaction permission result pending=${stale.pendingActive} " +
                        "pendingAccount=${stale.pendingAccountId} " +
                        "currentAccount=${stale.currentAccountId} loggedIn=${stale.mockLoggedIn}"
                )
            }
        )
    )
}
