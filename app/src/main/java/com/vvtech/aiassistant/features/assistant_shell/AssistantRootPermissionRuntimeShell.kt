package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.*

import android.content.Context
import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.features.assistant.AssistantContactRuntimeController
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.CoroutineScope

internal data class AssistantRootPermissionRuntimeDeps(
    val context: Context,
    val scope: CoroutineScope,
    val assistantUiState: Index9AssistantUiState,
    val taskEntry: AssistantTaskEntryState,
    val permissionOverlayState: AssistantPermissionOverlayState,
    val transientOverlayState: AssistantRootTransientOverlayState,
    val contactRuntime: AssistantContactRuntimeController,
    val navigationState: AssistantNavigationState,
    val assistantViewModel: AssistantViewModel,
    val mockLoggedInProvider: () -> Boolean
)

internal data class AssistantRootPermissionRuntimeCallbacks(
    val onVoiceCloneAudioPermissionResult: (Boolean) -> Unit,
    val onTranslationAudioPermissionGranted: () -> Unit,
    val onShowMessage: (String) -> Unit,
    val onLoadLocationIfPermitted: () -> Unit,
    val onTrustedCalleeStartupReadyChange: (Boolean) -> Unit,
    val onClearPendingVoiceEntryState: () -> Unit,
    val log: (String) -> Unit
)

internal class AssistantRootPermissionRuntime(
    val rootActivityLaunchers: AssistantRootActivityLaunchers,
    val voicePermissionLaunchers: AssistantVoicePermissionLaunchers,
    val contactPermissionLaunchers: AssistantContactPermissionLaunchers
)

@Composable
internal fun rememberAssistantRootPermissionRuntime(
    deps: AssistantRootPermissionRuntimeDeps,
    callbacks: AssistantRootPermissionRuntimeCallbacks
): AssistantRootPermissionRuntime {
    val rootActivityLauncherCallbacks = buildAssistantRootActivityLauncherCallbacks(
        AssistantRootActivityLauncherCallbackFactoryDeps(
            consumeAgentPermissionRequest = {
                deps.transientOverlayState.consumeAgentPermissionRequest(
                    deps.assistantUiState.agentPermissionRequest
                )
            },
            isAgentPermissionGranted = { request ->
                isAssistantAgentPermissionGranted(deps.context, request)
            },
            onAgentPermissionResult = { request, status, granted, message ->
                deps.assistantViewModel.onAgentPermissionResult(
                    permissionKey = request.permissionKey,
                    androidPermission = request.androidPermission,
                    status = status,
                    granted = granted,
                    message = message
                )
            },
            onClearAgentDocumentRequest = deps.transientOverlayState::clearAgentDocumentRequest,
            onAgentDocumentPickerCancelled = deps.assistantViewModel::onAgentDocumentPickerCancelled,
            onAgentDocumentPicked = deps.assistantViewModel::onAgentDocumentPicked,
            onVoiceCloneAudioPermissionResult = callbacks.onVoiceCloneAudioPermissionResult,
            onMicrophonePermissionGrantedChange = {
                deps.permissionOverlayState.microphonePermissionGranted = it
            },
            onTranslationAudioPermissionGranted = callbacks.onTranslationAudioPermissionGranted,
            onShowMessage = callbacks.onShowMessage,
            onLoadLocationIfPermitted = callbacks.onLoadLocationIfPermitted,
            onTrustedCalleeStartupReadyChange = callbacks.onTrustedCalleeStartupReadyChange
        )
    )
    val rootActivityLaunchers = rememberAssistantRootActivityLaunchers(rootActivityLauncherCallbacks)
    val voicePermissionLaunchers = rememberAssistantVoicePermissionLaunchers(
        buildAssistantRootVoicePermissionLauncherCallbacks(
            AssistantRootVoicePermissionLauncherCallbackDeps(
                accountProvider = {
                    AssistantVoicePermissionAccountState(
                        currentAccountId = AccountIdentityProvider.accountId,
                        mockLoggedIn = deps.mockLoggedInProvider()
                    )
                },
                onMicrophonePermissionGrantedChange = {
                    deps.permissionOverlayState.microphonePermissionGranted = it
                },
                onPermissionDenied = {
                    callbacks.onShowMessage("请授予麦克风权限后再使用语音功能")
                },
                voiceEntryStateProvider = {
                    AssistantVoiceEntryPermissionState(
                        pendingActive = deps.taskEntry.pendingVoiceEntryActive,
                        pendingAccountId = deps.taskEntry.pendingVoiceEntryAccountId
                    )
                },
                voiceInteractionStateProvider = {
                    AssistantVoiceInteractionPermissionState(
                        pendingActive = deps.taskEntry.pendingVoiceInteractionPermissionActive,
                        pendingAccountId = deps.taskEntry.pendingVoiceInteractionAccountId,
                        forceNewTaskEntry = deps.taskEntry.pendingVoiceInteractionForceNewTaskEntry,
                        useToggle = deps.taskEntry.pendingVoiceInteractionUseToggle
                    )
                },
                onVoiceEntryGrantedSignal = { deps.taskEntry.voiceEntryPermissionGrantedSignal += 1L },
                onClearPendingVoiceEntryState = callbacks.onClearPendingVoiceEntryState,
                onClearPendingVoiceInteractionState = {
                    deps.taskEntry.pendingVoiceInteractionPermissionActive = false
                    deps.taskEntry.pendingVoiceInteractionAccountId = ""
                    deps.taskEntry.pendingVoiceInteractionForceNewTaskEntry = false
                    deps.taskEntry.pendingVoiceInteractionUseToggle = false
                },
                onToggleVoiceInput = deps.assistantViewModel::toggleVoiceInputFromUser,
                onStartNewTaskEntry = deps.assistantViewModel::startVoiceInteractionForNewTaskEntry,
                onApiMicClick = deps.assistantViewModel::onApiMicClick,
                log = callbacks.log
            )
        )
    )
    val contactPermissionRuntime = rememberAssistantRootContactPermissionRuntime(
        AssistantRootContactPermissionRuntimeDeps(
            context = deps.context,
            scope = deps.scope,
            assistantUiState = deps.assistantUiState,
            contactsPermissionGranted = deps.permissionOverlayState.contactsPermissionGranted,
            contactRuntime = deps.contactRuntime,
            permissionOverlayState = deps.permissionOverlayState,
            navigationState = deps.navigationState,
            assistantViewModel = deps.assistantViewModel
        )
    )
    return AssistantRootPermissionRuntime(
        rootActivityLaunchers = rootActivityLaunchers,
        voicePermissionLaunchers = voicePermissionLaunchers,
        contactPermissionLaunchers = contactPermissionRuntime.launchers
    )
}
