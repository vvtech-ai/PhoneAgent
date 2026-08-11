package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.ui.unit.Dp
import com.vvtech.aiassistant.features.assistant.AssistantPageArgs
import com.vvtech.aiassistant.features.assistant.AssistantPageHostArgs
import com.vvtech.aiassistant.features.assistant.CallPageArgs
import com.vvtech.aiassistant.features.assistant.ConfirmClarifyArgs
import com.vvtech.aiassistant.features.assistant.ContactPageArgs
import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.PageHostNavigationArgs
import com.vvtech.aiassistant.features.assistant.PermissionDeveloperArgs
import com.vvtech.aiassistant.features.assistant.ProviderSettingsArgs
import com.vvtech.aiassistant.features.assistant.SettingsPageArgs
import com.vvtech.aiassistant.features.assistant.TaskPageArgs
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.VoiceCloneArgs

internal class AssistantPageHostArgsBuilderInput(
    val navigation: PageHostNavigationArgs,
    val assistant: AssistantPageArgs,
    val contact: ContactPageArgs,
    val call: CallPageArgs,
    val task: TaskPageArgs,
    val settings: SettingsPageArgs,
    val providerSettings: ProviderSettingsArgs,
    val voiceClone: VoiceCloneArgs,
    val confirmClarify: ConfirmClarifyArgs,
    val permissionDeveloper: PermissionDeveloperArgs
)

internal fun buildAssistantPageHostArgs(
    input: AssistantPageHostArgsBuilderInput
): AssistantPageHostArgs = AssistantPageHostArgs(
    navigation = input.navigation,
    assistant = input.assistant,
    contact = input.contact,
    call = input.call,
    task = input.task,
    settings = input.settings,
    providerSettings = input.providerSettings,
    voiceClone = input.voiceClone,
    confirmClarify = input.confirmClarify,
    permissionDeveloper = input.permissionDeveloper
)

internal class AssistantPageHostNavigationInput(
    val state: AssistantPageHostNavigationState,
    val callbacks: AssistantPageHostNavigationCallbacks
)

internal class AssistantPageHostNavigationState(
    val pageBottomInset: Dp,
    val currentPage: FinalPage
)

internal class AssistantPageHostNavigationCallbacks(
    val onPageChange: (FinalPage) -> Unit,
    val onMainTabChange: (FinalMainTab) -> Unit,
    val onTaskPageEntered: () -> Unit,
    val onOpenSubPage: (FinalPage) -> Unit,
    val onOpenSingleFlow: (String, Boolean) -> Unit,
    val onStartContactSkill: (String, String, String) -> Boolean,
    val onOpenMyIdentityVoiceModelSettings: () -> Unit,
    val onOpenSingleFlowDefault: () -> Unit,
    val onResumeSingleFlow: (Boolean) -> Unit,
    val onPauseTaskFlowAndReturnToPreviousTab: (String) -> Unit,
    val onRestartSingleFlow: () -> Unit,
    val onGoHomePreservingSession: () -> Unit,
    val onBackToMainTab: () -> Unit
)

internal fun buildAssistantPageHostNavigationArgs(
    input: AssistantPageHostNavigationInput
): PageHostNavigationArgs = PageHostNavigationArgs().also { args ->
    with(input.state) {
        args.pageBottomInset = pageBottomInset
        args.currentPage = currentPage
    }
    with(input.callbacks) {
        args.onPageChange = onPageChange
        args.onMainTabChange = onMainTabChange
        args.onTaskPageEntered = onTaskPageEntered
        args.onOpenSubPage = onOpenSubPage
        args.onOpenSingleFlow = onOpenSingleFlow
        args.onStartContactSkill = onStartContactSkill
        args.onOpenMyIdentityVoiceModelSettings = onOpenMyIdentityVoiceModelSettings
        args.onOpenSingleFlowDefault = onOpenSingleFlowDefault
        args.onResumeSingleFlow = onResumeSingleFlow
        args.onPauseTaskFlowAndReturnToPreviousTab = onPauseTaskFlowAndReturnToPreviousTab
        args.onRestartSingleFlow = onRestartSingleFlow
        args.onGoHomePreservingSession = onGoHomePreservingSession
        args.onBackToMainTab = onBackToMainTab
    }
}

internal class AssistantPermissionDeveloperArgsBuilderInput(
    val state: AssistantPermissionDeveloperState,
    val callbacks: AssistantPermissionDeveloperCallbacks
)

internal class AssistantPermissionDeveloperState(
    val developerDataMode: String,
    val networkMode: V88NetworkMode,
    val context: Context
)

internal class AssistantPermissionDeveloperCallbacks(
    val onNetworkModeNameChange: (String) -> Unit,
    val onShowNetworkBlockerChange: (Boolean) -> Unit,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onStoragePermissionGrantedChange: (Boolean) -> Unit,
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val onPhonePermissionGrantedChange: (Boolean) -> Unit,
    val onResetDialerLocationPermissionAndOpenDialSheet: () -> Unit,
    val onApplyDeveloperDataMode: (DeveloperDataMode) -> Unit
)

internal fun buildAssistantPermissionDeveloperArgs(
    input: AssistantPermissionDeveloperArgsBuilderInput
): PermissionDeveloperArgs = PermissionDeveloperArgs().also { args ->
    with(input.state) {
        args.developerDataMode = developerDataMode
        args.networkMode = networkMode
        args.context = context
    }
    with(input.callbacks) {
        args.onNetworkModeNameChange = onNetworkModeNameChange
        args.onShowNetworkBlockerChange = onShowNetworkBlockerChange
        args.onMicrophonePermissionGrantedChange = onMicrophonePermissionGrantedChange
        args.onStoragePermissionGrantedChange = onStoragePermissionGrantedChange
        args.onContactsPermissionGrantedChange = onContactsPermissionGrantedChange
        args.onPhonePermissionGrantedChange = onPhonePermissionGrantedChange
        args.onResetDialerLocationPermissionAndOpenDialSheet =
            onResetDialerLocationPermissionAndOpenDialSheet
        args.onApplyDeveloperDataMode = onApplyDeveloperDataMode
    }
}
