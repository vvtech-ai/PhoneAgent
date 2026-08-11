package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.callengine.AssistantClientCallState
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.assistant_shell.AssistantAccountOverlaySection
import com.vvtech.aiassistant.features.assistant_shell.AssistantNavigationCallOverlaySection
import com.vvtech.aiassistant.features.assistant_shell.AssistantPermissionGuideModelOverlaySection
import com.vvtech.aiassistant.features.assistant_model.AiCallModelLatencySource
import com.vvtech.aiassistant.features.assistant_model.PendingBackendAiCallModelLatencySource
import com.vvtech.aiassistant.features.app_ota.FinalOtaInstallUiState
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiAction
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState

internal class AssistantOverlayHostArgs {
    var showBottomTabs: Boolean = false
    lateinit var currentMainTab: FinalMainTab
    lateinit var onSelectMainTab: (FinalMainTab) -> Unit
    var assistantNavHidden: Boolean = false
    var taskBadgeCount: Int = 0
    var pureVoiceMode: Boolean = false
    lateinit var currentPage: FinalPage
    var selectedRestaurantTitle: String? = null
    var activeCallModelTitle: String = AssistantCallModelDisplayNames.Qwen
    lateinit var assistantUiState: Index9AssistantUiState
    var aiCallSeconds: Int = 0
    lateinit var onAiHangup: () -> Unit
    lateinit var onAiMonitorToggle: () -> Unit
    lateinit var onAiAudioRouteSelect: (CallMonitorAudioRoute) -> Unit
    var showCallsDialSheet: Boolean = false
    var dialInput: String = ""
    var translateDialEnabled: Boolean = false
    lateinit var onTranslateDialToggle: (Boolean) -> Unit
    var activeTranslationProviderTitle: String = "Qwen LT Flash"
    var activeTranslationProvider: String = "QWEN_OMNI_PLUS"
    var availableTranslationProviders: Set<String> =
        setOf("QWEN_OMNI_PLUS", "DOUBAO")
    var translationModelQuality: TranslationModelNetworkQualityState =
        TranslationModelNetworkQualityState()
    var onRefreshTranslationModelQuality: () -> Unit = {}
    lateinit var onSelectTranslationProvider: (String) -> Unit
    lateinit var onDialDigit: (String) -> Unit
    lateinit var onDialDelete: () -> Unit
    lateinit var onDialSheetClose: () -> Unit
    lateinit var onDial: () -> Unit
    var onOpenDialSheet: () -> Unit = {}
    var dialHistory: List<FinalCallRecord> = emptyList()
    var onDialHistorySelect:
        (com.vvtech.aiassistant.features.assistant_calls.DialTargetSelection) -> Unit = {}
    var onDialHistoryCall:
        (com.vvtech.aiassistant.features.assistant_calls.DialTargetSelection) -> Unit = {}
    var promptBeforeTranslationDial: Boolean = true
    var onPromptBeforeTranslationDialChange: (Boolean) -> Unit = {}
    var myTranslationLanguage: String = "中文"
    var otherTranslationLanguage: String = "英文"
    var onMyTranslationLanguageChange: (String) -> Unit = {}
    var onOtherTranslationLanguageChange: (String) -> Unit = {}
    var selectedDialCountryIso: String = "CN"
    var onSelectedDialCountryChange: (String) -> Unit = {}
    var dialLocationPromptShown: Boolean = false
    var onDialLocationPromptShownChange: (Boolean) -> Unit = {}
    var dialLocationSystemPermissionRequested: Boolean = false
    var onDialLocationSystemPermissionRequestedChange: (Boolean) -> Unit = {}
    var dialCallLogPermissionRequested: Boolean = false
    var onDialCallLogPermissionRequestedChange: (Boolean) -> Unit = {}
    var clientCallState: AssistantClientCallState = AssistantClientCallState()
    var onClientCallTick: () -> Unit = {}
    var onClientCallToggleMuted: () -> Unit = {}
    var onClientCallToggleSpeaker: () -> Unit = {}
    var onClientCallDtmf: (Char) -> Unit = {}
    var onClientCallHangup: () -> Unit = {}
    var translationCallState: TranslationCallUiState = TranslationCallUiState()
    var onTranslationCallAction: (TranslationCallUiAction) -> Unit = {}
    var onTranslationCallTick: () -> Unit = {}
    lateinit var networkMode: V88NetworkMode
    var showNetworkBlocker: Boolean = false
    lateinit var onNetworkRetry: () -> Unit
    lateinit var onDismissNetworkBlocker: () -> Unit
    var requestedPermission: V88PermissionKind? = null
    lateinit var onPermissionAllow: (V88PermissionKind) -> Unit
    lateinit var onPermissionDeny: (V88PermissionKind) -> Unit
    var showVoiceCloneGuide: Boolean = false
    lateinit var onStartVoiceCloneGuide: () -> Unit
    lateinit var onDismissVoiceCloneGuide: () -> Unit
    lateinit var onNeverAskVoiceCloneGuide: () -> Unit
    var showTrustedCalleeGuide: Boolean = false
    lateinit var onAuthorizeTrustedCallee: () -> Unit
    lateinit var onDismissTrustedCalleeGuide: () -> Unit
    lateinit var onNeverAskTrustedCalleeGuide: () -> Unit
    var showTrustedCalleeSecondModal: Boolean = false
    lateinit var onConfirmTrustedCalleeSecondModal: () -> Unit
    var showVoiceModelSheet: Boolean = false
    var selectedVoiceModelId: String = ""
    var availableVoiceModelIds: Set<String> = emptySet()
    var voiceModelOptions: List<V88VoiceModelOption> = emptyList()
    var voiceModelLatencySource: AiCallModelLatencySource =
        PendingBackendAiCallModelLatencySource
    lateinit var onSelectVoiceModel: (String) -> Unit
    lateinit var onCloseVoiceModelSheet: () -> Unit
    var otaUpdateDialog: FinalOtaUpdateDialogState? = null
    lateinit var otaInstallState: FinalOtaInstallUiState
    lateinit var onDismissOtaDialog: (FinalOtaUpdateDialogState) -> Unit
    lateinit var onOtaPrimaryAction: (FinalOtaUpdateDialogState) -> Unit
    var showLogoutConfirm: Boolean = false
    lateinit var onConfirmLogout: () -> Unit
    lateinit var onCancelLogout: () -> Unit
    var identityOverlaySaving: Boolean = false
    var identityOverlayError: String? = null
    var identityCompletionOnly: Boolean = false
    var initialIdentity: com.vvtech.aiassistant.data.model.UserIdentityPayload? = null
    var initialTranslationProvider: String = "QWEN_OMNI_PLUS"
    lateinit var onDismissIdentityOverlay: () -> Unit
    lateinit var onSkipIdentityForSession: () -> Unit
    lateinit var onSubmitIdentityOverlay: (com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest) -> Unit
    lateinit var onSelectInitializationCallProvider: (String) -> Unit
    lateinit var onSelectInitializationTranslationProvider: (String) -> Unit
    lateinit var onAgentDeviceContactSelectionConfirm: (Map<String, DeviceContactSelectionCandidateUi>) -> Unit
    lateinit var onAgentDeviceContactSelectionCancel: () -> Unit
}

@Composable
internal fun BoxScope.AssistantOverlayHost(args: AssistantOverlayHostArgs) {
    AssistantNavigationCallOverlaySection(args)
    AssistantPermissionGuideModelOverlaySection(args)
    AssistantAccountOverlaySection(args)
}
