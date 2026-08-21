package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.callengine.AssistantClientCallState
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.features.assistant.AssistantOverlayHostArgs
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRoute
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import com.vvtech.aiassistant.features.assistant.V88VoiceModelOption
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage

internal data class AssistantRootOverlayArgsFactoryDeps(
    val navigation: AssistantRootOverlayNavigationDeps,
    val aiCall: AssistantRootOverlayAiCallDeps,
    val dial: AssistantRootOverlayDialDeps,
    val permission: AssistantRootOverlayPermissionDeps,
    val guide: AssistantRootOverlayGuideDeps,
    val model: AssistantRootOverlayModelDeps,
    val account: AssistantRootOverlayAccountDeps
)

internal data class AssistantRootOverlayNavigationDeps(
    val showBottomTabs: Boolean,
    val currentMainTab: FinalMainTab,
    val onSelectMainTab: (FinalMainTab) -> Unit,
    val assistantNavHidden: Boolean,
    val taskBadgeCount: Int,
    val pureVoiceMode: Boolean,
    val currentPage: FinalPage,
    val appLanguage: AppLanguage = AppLanguage.English
)

internal data class AssistantRootOverlayAiCallDeps(
    val selectedRestaurantTitle: String?,
    val activeCallModelTitle: String,
    val assistantUiState: Index9AssistantUiState,
    val aiCallSeconds: Int,
    val onAiHangup: () -> Unit,
    val onAiMonitorToggle: () -> Unit,
    val onAiAudioRouteSelect: (CallMonitorAudioRoute) -> Unit
)

internal data class AssistantRootOverlayDialDeps(
    val showCallsDialSheet: Boolean,
    val dialInput: String,
    val translateDialEnabled: Boolean,
    val onTranslateDialToggle: (Boolean) -> Unit,
    val activeTranslationProviderTitle: String = "Qwen LT Flash",
    val activeTranslationProvider: String = "QWEN_OMNI_PLUS",
    val onSelectTranslationProvider: (String) -> Unit = {},
    val onDialDigit: (String) -> Unit,
    val onDialDelete: () -> Unit,
    val onDialSheetClose: () -> Unit,
    val onDial: () -> Unit,
    val onOpenDialSheet: () -> Unit = {},
    val history: List<FinalCallRecord> = emptyList(),
    val onHistorySelect: (com.vvtech.aiassistant.features.assistant_calls.DialTargetSelection) -> Unit = {},
    val onHistoryCall: (com.vvtech.aiassistant.features.assistant_calls.DialTargetSelection) -> Unit = {},
    val promptBeforeTranslationDial: Boolean = true,
    val onPromptBeforeTranslationDialChange: (Boolean) -> Unit = {},
    val myLanguage: String = "中文",
    val otherLanguage: String = "英文",
    val onMyLanguageChange: (String) -> Unit = {},
    val onOtherLanguageChange: (String) -> Unit = {},
    val selectedCountryIso: String = "CN",
    val onSelectedCountryChange: (String) -> Unit = {},
    val locationPromptShown: Boolean = false,
    val onLocationPromptShownChange: (Boolean) -> Unit = {},
    val locationSystemPermissionRequested: Boolean = false,
    val onLocationSystemPermissionRequestedChange: (Boolean) -> Unit = {},
    val callLogPermissionRequested: Boolean = false,
    val onCallLogPermissionRequestedChange: (Boolean) -> Unit = {},
    val clientCallState: AssistantClientCallState = AssistantClientCallState(),
    val onClientCallTick: () -> Unit = {},
    val onClientCallToggleMuted: () -> Unit = {},
    val onClientCallToggleSpeaker: () -> Unit = {},
    val onClientCallDtmf: (Char) -> Unit = {},
    val onClientCallHangup: () -> Unit = {}
)

internal data class AssistantRootOverlayPermissionDeps(
    val state: AssistantRootOverlayPermissionState,
    val callbacks: AssistantRootOverlayPermissionCallbacks
)

internal data class AssistantRootOverlayPermissionState(
    val networkMode: V88NetworkMode,
    val showNetworkBlocker: Boolean,
    val requestedPermission: V88PermissionKind?
)

internal data class AssistantRootOverlayPermissionCallbacks(
    val onShowMessage: (String) -> Unit,
    val onShowNetworkBlockerChange: (Boolean) -> Unit,
    val onRequestedPermissionNameChange: (String?) -> Unit,
    val onPendingPermissionActionChange: (String) -> Unit,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onStoragePermissionGrantedChange: (Boolean) -> Unit,
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val onPhonePermissionGrantedChange: (Boolean) -> Unit,
    val onLaunchContactsPermission: () -> Unit,
    val onRunPendingPermissionAction: () -> Unit,
    val onGoHomeAfterContactsDenied: () -> Unit,
    val onDismissNetworkBlocker: () -> Unit
)

internal data class AssistantRootOverlayGuideDeps(
    val showVoiceCloneGuide: Boolean,
    val onStartVoiceCloneGuide: () -> Unit,
    val onDismissVoiceCloneGuide: () -> Unit,
    val onNeverAskVoiceCloneGuide: () -> Unit,
    val onApplyTrustedCalleeOverlayArgs: (AssistantOverlayHostArgs) -> Unit
)

internal data class AssistantRootOverlayModelDeps(
    val state: AssistantRootOverlayModelState,
    val callbacks: AssistantRootOverlayModelCallbacks
)

internal data class AssistantRootOverlayModelState(
    val showVoiceModelSheet: Boolean,
    val selectedVoiceModelId: String,
    val availableVoiceModelIds: Set<String>,
    val voiceModelOptions: List<V88VoiceModelOption>,
    val realtimeProviderSwitching: Boolean
)

internal data class AssistantRootOverlayModelCallbacks(
    val onShowMessage: (String) -> Unit,
    val onShowVoiceModelSheetChange: (Boolean) -> Unit,
    val onSwitchRealtimeCallProvider: (String) -> Unit,
    val onCloseVoiceModelSheet: () -> Unit
)

internal data class AssistantRootOverlayAccountDeps(
    val onApplyOtaOverlayArgs: (AssistantOverlayHostArgs) -> Unit,
    val onApplyLogoutOverlayArgs: (AssistantOverlayHostArgs) -> Unit,
    val identityOverlaySaving: Boolean,
    val identityOverlayError: String?,
    val identityCompletionOnly: Boolean,
    val initialIdentity: UserIdentityPayload?,
    val initialTranslationProvider: String = "QWEN_OMNI_PLUS",
    val onDismissIdentityOverlay: () -> Unit,
    val onSkipIdentityForSession: () -> Unit,
    val onSubmitIdentityOverlay: (UserIdentityUpsertRequest) -> Unit,
    val onSelectInitializationCallProvider: (String) -> Unit = {},
    val onSelectInitializationTranslationProvider: (String) -> Unit = {},
    val onAgentDeviceContactSelectionConfirm: (Map<String, DeviceContactSelectionCandidateUi>) -> Unit,
    val onAgentDeviceContactSelectionCancel: () -> Unit
)

internal fun buildAssistantRootOverlayArgs(
    deps: AssistantRootOverlayArgsFactoryDeps
): AssistantOverlayHostArgs {
    val permissionActionCallbacks = AssistantOverlayPermissionActionCallbacks(
        onShowMessage = deps.permission.callbacks.onShowMessage,
        onShowNetworkBlockerChange = deps.permission.callbacks.onShowNetworkBlockerChange,
        onRequestedPermissionNameChange = deps.permission.callbacks.onRequestedPermissionNameChange,
        onPendingPermissionActionChange = deps.permission.callbacks.onPendingPermissionActionChange,
        onMicrophonePermissionGrantedChange = deps.permission.callbacks.onMicrophonePermissionGrantedChange,
        onStoragePermissionGrantedChange = deps.permission.callbacks.onStoragePermissionGrantedChange,
        onContactsPermissionGrantedChange = deps.permission.callbacks.onContactsPermissionGrantedChange,
        onPhonePermissionGrantedChange = deps.permission.callbacks.onPhonePermissionGrantedChange,
        onLaunchContactsPermission = deps.permission.callbacks.onLaunchContactsPermission,
        onRunPendingPermissionAction = deps.permission.callbacks.onRunPendingPermissionAction,
        onGoHomeAfterContactsDenied = deps.permission.callbacks.onGoHomeAfterContactsDenied
    )
    val modelSelectionCallbacks = AssistantOverlayModelSelectionCallbacks(
        onShowMessage = deps.model.callbacks.onShowMessage,
        onShowVoiceModelSheetChange = deps.model.callbacks.onShowVoiceModelSheetChange,
        onSwitchRealtimeCallProvider = deps.model.callbacks.onSwitchRealtimeCallProvider
    )
    return buildAssistantOverlayArgs(
        AssistantOverlayArgsBuilderInput(
            navigation = AssistantOverlayNavigationInput(
                showBottomTabs = deps.navigation.showBottomTabs,
                currentMainTab = deps.navigation.currentMainTab,
                onSelectMainTab = deps.navigation.onSelectMainTab,
                assistantNavHidden = deps.navigation.assistantNavHidden,
                taskBadgeCount = deps.navigation.taskBadgeCount,
                pureVoiceMode = deps.navigation.pureVoiceMode,
                currentPage = deps.navigation.currentPage,
                appLanguage = deps.navigation.appLanguage
            ),
            aiCall = AssistantOverlayAiCallInput(
                selectedRestaurantTitle = deps.aiCall.selectedRestaurantTitle,
                activeCallModelTitle = deps.aiCall.activeCallModelTitle,
                assistantUiState = deps.aiCall.assistantUiState,
                aiCallSeconds = deps.aiCall.aiCallSeconds,
                onAiHangup = deps.aiCall.onAiHangup,
                onAiMonitorToggle = deps.aiCall.onAiMonitorToggle,
                onAiAudioRouteSelect = deps.aiCall.onAiAudioRouteSelect
            ),
            dial = AssistantOverlayDialInput(
                showCallsDialSheet = deps.dial.showCallsDialSheet,
                dialInput = deps.dial.dialInput,
                translateDialEnabled = deps.dial.translateDialEnabled,
                onTranslateDialToggle = deps.dial.onTranslateDialToggle,
                activeTranslationProviderTitle = deps.dial.activeTranslationProviderTitle,
                activeTranslationProvider = deps.dial.activeTranslationProvider,
                onSelectTranslationProvider = deps.dial.onSelectTranslationProvider,
                onDialDigit = deps.dial.onDialDigit,
                onDialDelete = deps.dial.onDialDelete,
                onDialSheetClose = deps.dial.onDialSheetClose,
                onDial = deps.dial.onDial,
                onOpenDialSheet = deps.dial.onOpenDialSheet,
                history = deps.dial.history,
                onHistorySelect = deps.dial.onHistorySelect,
                onHistoryCall = deps.dial.onHistoryCall,
                promptBeforeTranslationDial = deps.dial.promptBeforeTranslationDial,
                onPromptBeforeTranslationDialChange = deps.dial.onPromptBeforeTranslationDialChange,
                myLanguage = deps.dial.myLanguage,
                otherLanguage = deps.dial.otherLanguage,
                onMyLanguageChange = deps.dial.onMyLanguageChange,
                onOtherLanguageChange = deps.dial.onOtherLanguageChange,
                selectedCountryIso = deps.dial.selectedCountryIso,
                onSelectedCountryChange = deps.dial.onSelectedCountryChange,
                locationPromptShown = deps.dial.locationPromptShown,
                onLocationPromptShownChange = deps.dial.onLocationPromptShownChange,
                locationSystemPermissionRequested =
                    deps.dial.locationSystemPermissionRequested,
                onLocationSystemPermissionRequestedChange =
                    deps.dial.onLocationSystemPermissionRequestedChange,
                callLogPermissionRequested = deps.dial.callLogPermissionRequested,
                onCallLogPermissionRequestedChange =
                    deps.dial.onCallLogPermissionRequestedChange,
                clientCallState = deps.dial.clientCallState,
                onClientCallTick = deps.dial.onClientCallTick,
                onClientCallToggleMuted = deps.dial.onClientCallToggleMuted,
                onClientCallToggleSpeaker = deps.dial.onClientCallToggleSpeaker,
                onClientCallDtmf = deps.dial.onClientCallDtmf,
                onClientCallHangup = deps.dial.onClientCallHangup
            ),
            permission = AssistantOverlayPermissionInput(
                networkMode = deps.permission.state.networkMode,
                showNetworkBlocker = deps.permission.state.showNetworkBlocker,
                onNetworkRetry = {
                    handleOverlayNetworkRetry(
                        state = AssistantOverlayPermissionActionState(deps.permission.state.networkMode),
                        callbacks = permissionActionCallbacks
                    )
                },
                onDismissNetworkBlocker = deps.permission.callbacks.onDismissNetworkBlocker,
                requestedPermission = deps.permission.state.requestedPermission,
                onPermissionAllow = { permission ->
                    handleOverlayPermissionAllow(permission, permissionActionCallbacks)
                },
                onPermissionDeny = { permission ->
                    handleOverlayPermissionDeny(permission, permissionActionCallbacks)
                }
            ),
            guide = AssistantOverlayGuideInput(
                showVoiceCloneGuide = deps.guide.showVoiceCloneGuide,
                onStartVoiceCloneGuide = deps.guide.onStartVoiceCloneGuide,
                onDismissVoiceCloneGuide = deps.guide.onDismissVoiceCloneGuide,
                onNeverAskVoiceCloneGuide = deps.guide.onNeverAskVoiceCloneGuide,
                onApplyTrustedCalleeOverlayArgs = deps.guide.onApplyTrustedCalleeOverlayArgs
            ),
            model = AssistantOverlayModelInput(
                showVoiceModelSheet = deps.model.state.showVoiceModelSheet,
                selectedVoiceModelId = deps.model.state.selectedVoiceModelId,
                availableVoiceModelIds = deps.model.state.availableVoiceModelIds,
                voiceModelOptions = deps.model.state.voiceModelOptions,
                onSelectVoiceModel = { modelId ->
                    handleOverlayVoiceModelSelection(
                        modelId = modelId,
                        state = AssistantOverlayModelSelectionState(
                            selectedVoiceModelId = deps.model.state.selectedVoiceModelId,
                            availableVoiceModelIds = deps.model.state.availableVoiceModelIds,
                            realtimeProviderSwitching = deps.model.state.realtimeProviderSwitching
                        ),
                        callbacks = modelSelectionCallbacks
                    )
                },
                onCloseVoiceModelSheet = deps.model.callbacks.onCloseVoiceModelSheet
            ),
            account = AssistantOverlayAccountInput(
                onApplyOtaOverlayArgs = deps.account.onApplyOtaOverlayArgs,
                onApplyLogoutOverlayArgs = deps.account.onApplyLogoutOverlayArgs,
                identityOverlaySaving = deps.account.identityOverlaySaving,
                identityOverlayError = deps.account.identityOverlayError,
                identityCompletionOnly = deps.account.identityCompletionOnly,
                initialIdentity = deps.account.initialIdentity,
                initialTranslationProvider = deps.account.initialTranslationProvider,
                onDismissIdentityOverlay = deps.account.onDismissIdentityOverlay,
                onSkipIdentityForSession = deps.account.onSkipIdentityForSession,
                onSubmitIdentityOverlay = deps.account.onSubmitIdentityOverlay,
                onSelectInitializationCallProvider = deps.account.onSelectInitializationCallProvider,
                onSelectInitializationTranslationProvider = deps.account.onSelectInitializationTranslationProvider,
                onAgentDeviceContactSelectionConfirm = deps.account.onAgentDeviceContactSelectionConfirm,
                onAgentDeviceContactSelectionCancel = deps.account.onAgentDeviceContactSelectionCancel
            )
        )
    )
}
