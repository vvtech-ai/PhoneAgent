package com.vvtech.aiassistant.features.assistant_shell

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable

internal class AssistantVoicePermissionLaunchers(
    val voiceEntry: ActivityResultLauncher<String>,
    val voiceInteraction: ActivityResultLauncher<String>
)

internal data class AssistantVoicePermissionAccountState(
    val currentAccountId: String,
    val mockLoggedIn: Boolean
)

internal data class AssistantVoiceEntryPermissionState(
    val pendingActive: Boolean,
    val pendingAccountId: String
)

internal data class AssistantVoiceInteractionPermissionState(
    val pendingActive: Boolean,
    val pendingAccountId: String,
    val forceNewTaskEntry: Boolean,
    val useToggle: Boolean
)

internal data class AssistantVoicePermissionStaleResult(
    val pendingActive: Boolean,
    val pendingAccountId: String,
    val currentAccountId: String,
    val mockLoggedIn: Boolean
)

internal class AssistantVoiceEntryPermissionCallbacks(
    val stateProvider: () -> AssistantVoiceEntryPermissionState,
    val onGrantedSignal: () -> Unit,
    val onClearPending: () -> Unit,
    val onDropStale: (AssistantVoicePermissionStaleResult) -> Unit
)

internal class AssistantVoiceInteractionPermissionCallbacks(
    val stateProvider: () -> AssistantVoiceInteractionPermissionState,
    val onToggleVoiceInput: () -> Unit,
    val onStartNewTaskEntry: () -> Unit,
    val onApiMicClick: () -> Unit,
    val onClearPending: () -> Unit,
    val onDropStale: (AssistantVoicePermissionStaleResult) -> Unit
)

internal class AssistantVoicePermissionLauncherCallbacks(
    val accountProvider: () -> AssistantVoicePermissionAccountState,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onPermissionDenied: () -> Unit,
    val voiceEntry: AssistantVoiceEntryPermissionCallbacks,
    val voiceInteraction: AssistantVoiceInteractionPermissionCallbacks
)

@Composable
internal fun rememberAssistantVoicePermissionLaunchers(
    callbacks: AssistantVoicePermissionLauncherCallbacks
): AssistantVoicePermissionLaunchers {
    val voiceEntry = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        handleAssistantVoiceEntryPermissionResult(granted, callbacks)
    }
    val voiceInteraction = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        handleAssistantVoiceInteractionPermissionResult(granted, callbacks)
    }
    return AssistantVoicePermissionLaunchers(
        voiceEntry = voiceEntry,
        voiceInteraction = voiceInteraction
    )
}

internal fun handleAssistantVoiceEntryPermissionResult(
    granted: Boolean,
    callbacks: AssistantVoicePermissionLauncherCallbacks
) {
    callbacks.onMicrophonePermissionGrantedChange(granted)
    if (!granted) {
        callbacks.voiceEntry.onClearPending()
        callbacks.onPermissionDenied()
        return
    }
    val account = callbacks.accountProvider()
    val state = callbacks.voiceEntry.stateProvider()
    if (
        state.pendingActive &&
        account.currentAccountId.isNotBlank() &&
        state.pendingAccountId == account.currentAccountId &&
        account.mockLoggedIn
    ) {
        callbacks.voiceEntry.onGrantedSignal()
    } else {
        callbacks.voiceEntry.onDropStale(
            AssistantVoicePermissionStaleResult(
                pendingActive = state.pendingActive,
                pendingAccountId = state.pendingAccountId,
                currentAccountId = account.currentAccountId,
                mockLoggedIn = account.mockLoggedIn
            )
        )
        callbacks.voiceEntry.onClearPending()
    }
}

internal fun handleAssistantVoiceInteractionPermissionResult(
    granted: Boolean,
    callbacks: AssistantVoicePermissionLauncherCallbacks
) {
    callbacks.onMicrophonePermissionGrantedChange(granted)
    if (granted) {
        val account = callbacks.accountProvider()
        val state = callbacks.voiceInteraction.stateProvider()
        val validPendingInteraction = state.pendingActive &&
            account.currentAccountId.isNotBlank() &&
            state.pendingAccountId == account.currentAccountId &&
            account.mockLoggedIn
        if (!validPendingInteraction) {
            callbacks.voiceInteraction.onDropStale(
                AssistantVoicePermissionStaleResult(
                    pendingActive = state.pendingActive,
                    pendingAccountId = state.pendingAccountId,
                    currentAccountId = account.currentAccountId,
                    mockLoggedIn = account.mockLoggedIn
                )
            )
        } else if (state.useToggle) {
            callbacks.voiceInteraction.onToggleVoiceInput()
        } else if (state.forceNewTaskEntry) {
            callbacks.voiceInteraction.onStartNewTaskEntry()
        } else {
            callbacks.voiceInteraction.onApiMicClick()
        }
    } else {
        callbacks.onPermissionDenied()
    }
    callbacks.voiceInteraction.onClearPending()
}
