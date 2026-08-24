package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.callengine.AssistantClientCallState
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.features.assistant.AssistantOverlayHostArgs
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRoute
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import com.vvtech.aiassistant.features.assistant.V88VoiceModelOption
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage

internal class AssistantOverlayArgsBuilderInput(
    val navigation: AssistantOverlayNavigationInput,
    val aiCall: AssistantOverlayAiCallInput,
    val dial: AssistantOverlayDialInput,
    val permission: AssistantOverlayPermissionInput,
    val guide: AssistantOverlayGuideInput,
    val model: AssistantOverlayModelInput,
    val account: AssistantOverlayAccountInput
)

internal class AssistantOverlayNavigationInput(
    val showBottomTabs: Boolean,
    val currentMainTab: FinalMainTab,
    val onSelectMainTab: (FinalMainTab) -> Unit,
    val assistantNavHidden: Boolean,
    val taskBadgeCount: Int,
    val pureVoiceMode: Boolean,
    val currentPage: FinalPage,
    val appLanguage: AppLanguage
)

internal class AssistantOverlayAiCallInput(
    val selectedRestaurantTitle: String?,
    val activeCallModelTitle: String,
    val assistantUiState: Index9AssistantUiState,
    val aiCallSeconds: Int,
    val onAiHangup: () -> Unit,
    val onAiMonitorToggle: () -> Unit,
    val onAiAudioRouteSelect: (CallMonitorAudioRoute) -> Unit
)

internal class AssistantOverlayDialInput(
    val showCallsDialSheet: Boolean,
    val dialInput: String,
    val translateDialEnabled: Boolean,
    val onTranslateDialToggle: (Boolean) -> Unit,
    val activeTranslationProviderTitle: String,
    val activeTranslationProvider: String,
    val onSelectTranslationProvider: (String) -> Unit,
    val onDialDigit: (String) -> Unit,
    val onDialDelete: () -> Unit,
    val onDialSheetClose: () -> Unit,
    val onDial: () -> Unit,
    val onOpenDialSheet: () -> Unit = {},
    val history: List<com.vvtech.aiassistant.features.assistant.FinalCallRecord> = emptyList(),
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

internal class AssistantOverlayPermissionInput(
    val networkMode: V88NetworkMode,
    val showNetworkBlocker: Boolean,
    val onNetworkRetry: () -> Unit,
    val onDismissNetworkBlocker: () -> Unit,
    val requestedPermission: V88PermissionKind?,
    val onPermissionAllow: (V88PermissionKind) -> Unit,
    val onPermissionDeny: (V88PermissionKind) -> Unit
)

internal class AssistantOverlayGuideInput(
    val showVoiceCloneGuide: Boolean,
    val onStartVoiceCloneGuide: () -> Unit,
    val onDismissVoiceCloneGuide: () -> Unit,
    val onNeverAskVoiceCloneGuide: () -> Unit,
    val onApplyTrustedCalleeOverlayArgs: (AssistantOverlayHostArgs) -> Unit
)

internal class AssistantOverlayModelInput(
    val showVoiceModelSheet: Boolean,
    val selectedVoiceModelId: String,
    val availableVoiceModelIds: Set<String>,
    val voiceModelOptions: List<V88VoiceModelOption>,
    val onSelectVoiceModel: (String) -> Unit,
    val onCloseVoiceModelSheet: () -> Unit
)

internal class AssistantOverlayAccountInput(
    val onApplyOtaOverlayArgs: (AssistantOverlayHostArgs) -> Unit,
    val onApplyLogoutOverlayArgs: (AssistantOverlayHostArgs) -> Unit,
    val identityOverlaySaving: Boolean,
    val identityOverlayError: String?,
    val identityCompletionOnly: Boolean,
    val initialIdentity: UserIdentityPayload?,
    val initialTranslationProvider: String,
    val onDismissIdentityOverlay: () -> Unit,
    val onSkipIdentityForSession: () -> Unit,
    val onSubmitIdentityOverlay: (UserIdentityUpsertRequest) -> Unit,
    val onSelectInitializationCallProvider: (String) -> Unit,
    val onSelectInitializationTranslationProvider: (String) -> Unit,
    val onAgentDeviceContactSelectionConfirm: (Map<String, DeviceContactSelectionCandidateUi>) -> Unit,
    val onAgentDeviceContactSelectionCancel: () -> Unit
)

internal fun buildAssistantOverlayArgs(
    input: AssistantOverlayArgsBuilderInput
): AssistantOverlayHostArgs = AssistantOverlayHostArgs().also { args ->
    with(input.navigation) {
        args.showBottomTabs = showBottomTabs
        args.currentMainTab = currentMainTab
        args.onSelectMainTab = onSelectMainTab
        args.assistantNavHidden = assistantNavHidden
        args.taskBadgeCount = taskBadgeCount
        args.pureVoiceMode = pureVoiceMode
        args.currentPage = currentPage
        args.appLanguage = appLanguage
    }
    with(input.aiCall) {
        args.selectedRestaurantTitle = selectedRestaurantTitle
        args.activeCallModelTitle = activeCallModelTitle
        args.assistantUiState = assistantUiState
        args.aiCallSeconds = aiCallSeconds
        args.onAiHangup = onAiHangup
        args.onAiMonitorToggle = onAiMonitorToggle
        args.onAiAudioRouteSelect = onAiAudioRouteSelect
    }
    with(input.dial) {
        args.showCallsDialSheet = showCallsDialSheet
        args.dialInput = dialInput
        args.translateDialEnabled = translateDialEnabled
        args.onTranslateDialToggle = onTranslateDialToggle
        args.activeTranslationProviderTitle = activeTranslationProviderTitle
        args.activeTranslationProvider = activeTranslationProvider
        args.onSelectTranslationProvider = onSelectTranslationProvider
        args.onDialDigit = onDialDigit
        args.onDialDelete = onDialDelete
        args.onDialSheetClose = onDialSheetClose
        args.onDial = onDial
        args.onOpenDialSheet = onOpenDialSheet
        args.dialHistory = history
        args.onDialHistorySelect = onHistorySelect
        args.onDialHistoryCall = onHistoryCall
        args.promptBeforeTranslationDial = promptBeforeTranslationDial
        args.onPromptBeforeTranslationDialChange = onPromptBeforeTranslationDialChange
        args.myTranslationLanguage = myLanguage
        args.otherTranslationLanguage = otherLanguage
        args.onMyTranslationLanguageChange = onMyLanguageChange
        args.onOtherTranslationLanguageChange = onOtherLanguageChange
        args.selectedDialCountryIso = selectedCountryIso
        args.onSelectedDialCountryChange = onSelectedCountryChange
        args.dialLocationPromptShown = locationPromptShown
        args.onDialLocationPromptShownChange = onLocationPromptShownChange
        args.dialLocationSystemPermissionRequested = locationSystemPermissionRequested
        args.onDialLocationSystemPermissionRequestedChange =
            onLocationSystemPermissionRequestedChange
        args.dialCallLogPermissionRequested = callLogPermissionRequested
        args.onDialCallLogPermissionRequestedChange = onCallLogPermissionRequestedChange
        args.clientCallState = clientCallState
        args.onClientCallTick = onClientCallTick
        args.onClientCallToggleMuted = onClientCallToggleMuted
        args.onClientCallToggleSpeaker = onClientCallToggleSpeaker
        args.onClientCallDtmf = onClientCallDtmf
        args.onClientCallHangup = onClientCallHangup
    }
    with(input.permission) {
        args.networkMode = networkMode
        args.showNetworkBlocker = showNetworkBlocker
        args.onNetworkRetry = onNetworkRetry
        args.onDismissNetworkBlocker = onDismissNetworkBlocker
        args.requestedPermission = requestedPermission
        args.onPermissionAllow = onPermissionAllow
        args.onPermissionDeny = onPermissionDeny
    }
    with(input.guide) {
        args.showVoiceCloneGuide = showVoiceCloneGuide
        args.onStartVoiceCloneGuide = onStartVoiceCloneGuide
        args.onDismissVoiceCloneGuide = onDismissVoiceCloneGuide
        args.onNeverAskVoiceCloneGuide = onNeverAskVoiceCloneGuide
        onApplyTrustedCalleeOverlayArgs(args)
    }
    with(input.model) {
        args.showVoiceModelSheet = showVoiceModelSheet
        args.selectedVoiceModelId = selectedVoiceModelId
        args.availableVoiceModelIds = availableVoiceModelIds
        args.voiceModelOptions = voiceModelOptions
        args.onSelectVoiceModel = onSelectVoiceModel
        args.onCloseVoiceModelSheet = onCloseVoiceModelSheet
    }
    with(input.account) {
        onApplyOtaOverlayArgs(args)
        onApplyLogoutOverlayArgs(args)
        args.identityOverlaySaving = identityOverlaySaving
        args.identityOverlayError = identityOverlayError
        args.identityCompletionOnly = identityCompletionOnly
        args.initialIdentity = initialIdentity
        args.initialTranslationProvider = initialTranslationProvider
        args.onDismissIdentityOverlay = onDismissIdentityOverlay
        args.onSkipIdentityForSession = onSkipIdentityForSession
        args.onSubmitIdentityOverlay = onSubmitIdentityOverlay
        args.onSelectInitializationCallProvider = onSelectInitializationCallProvider
        args.onSelectInitializationTranslationProvider = onSelectInitializationTranslationProvider
        args.onAgentDeviceContactSelectionConfirm = onAgentDeviceContactSelectionConfirm
        args.onAgentDeviceContactSelectionCancel = onAgentDeviceContactSelectionCancel
    }
}
