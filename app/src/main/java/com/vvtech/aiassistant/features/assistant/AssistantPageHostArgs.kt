package com.vvtech.aiassistant.features.assistant

import android.content.SharedPreferences
import androidx.compose.ui.unit.Dp
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse
import com.vvtech.aiassistant.model.VoiceCloneScriptItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
internal class AssistantPageHostArgs(
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
internal class PageHostNavigationArgs {
    var pageBottomInset: Dp = Dp.Unspecified
    lateinit var currentPage: FinalPage
    lateinit var onPageChange: (FinalPage) -> Unit
    lateinit var onMainTabChange: (FinalMainTab) -> Unit
    lateinit var onTaskPageEntered: () -> Unit
    lateinit var onOpenSubPage: (FinalPage) -> Unit
    lateinit var onOpenSingleFlow: (String, Boolean) -> Unit
    lateinit var onStartContactSkill: (String, String, String) -> Boolean
    lateinit var onOpenMyIdentityVoiceModelSettings: () -> Unit
    lateinit var onOpenSingleFlowDefault: () -> Unit
    lateinit var onResumeSingleFlow: (Boolean) -> Unit
    lateinit var onPauseTaskFlowAndReturnToPreviousTab: (String) -> Unit
    lateinit var onRestartSingleFlow: () -> Unit
    lateinit var onGoHomePreservingSession: () -> Unit
    lateinit var onBackToMainTab: () -> Unit
}
internal class AssistantPageArgs {
    lateinit var assistantViewModel: AssistantViewModel
    lateinit var assistantUiState: Index9AssistantUiState
    var homeComposerOpen: Boolean = false
    lateinit var onHomeComposerOpenChange: (Boolean) -> Unit
    var effectiveTaskStarted: Boolean = false
    var effectiveTaskUserText: String = ""
    var effectiveAiThinking: Boolean = false
    var effectiveAiReplyVisible: Boolean = false
    var taskTextDraft: String = ""
    lateinit var onTaskTextDraftChange: (String) -> Unit
    var pureVoiceMode: Boolean = false
    var pureVoicePrecheck: PureVoicePrecheckUiState? = null
    var composerMode: String = ""
    lateinit var onComposerModeChange: (String) -> Unit
    lateinit var onQuickVoiceEntry: (String?) -> Boolean
    lateinit var onOpenTranslateDial: () -> Unit
    lateinit var onBlockHomeCardIfOffline: () -> Boolean
    var activeCallModelTitle: String = AssistantCallModelDisplayNames.Qwen
    lateinit var onOpenCallModelSheet: () -> Unit
    lateinit var onStartVoice: () -> Unit
    lateinit var onStopVoice: () -> Unit
    lateinit var onInterruptTts: () -> Unit
    lateinit var onSendText: () -> Unit
    lateinit var onStopTask: () -> Unit
    lateinit var onAgentDocumentSelect: () -> Unit
    lateinit var onAgentDocumentCancel: () -> Unit
    lateinit var onAgentSheetDismiss: () -> Unit
    lateinit var onReplayTts: (String) -> Unit
    var homeNotificationVisible: Boolean = false
    var homeNotificationText: String = ""
    var homeNotificationExtra: String = ""
    lateinit var homeNotificationStatusKind: FinalTaskStatusKind
    lateinit var onClickHomeNotification: () -> Unit
    lateinit var onDismissHomeNotification: () -> Unit
    var singleFlowInitialCommand: String = ""
    lateinit var onConsumeSingleFlowSelectedContact: () -> com.vvtech.aiassistant.core.model.SelectedContactTaskContext?
    var singleFlowStartInVoice: Boolean = false
    var singleFlowResumeListeningOnly: Boolean = false
    var singleFlowEntryKey: Long = 0L
    var singleFlowForceNewVoiceEntryStart: Boolean = false
    lateinit var onStartVoiceInteractionWithPermission: (forceNewTaskEntry: Boolean, useToggle: Boolean) -> Unit
    lateinit var onPersistTaskContactIfNeeded: (EffectiveTaskContact) -> EffectiveTaskContact
}
internal class ContactPageArgs {
    lateinit var voiceLanguage: VoiceLanguage
    var contactRecords: List<FinalContactRecord> = emptyList()
    var selectedContactName: String = ""
    var selectedContactPhone: String = ""
    var selectedContactSystemDialPhone: String = ""
    var selectedContactHint: String = ""
    lateinit var onSelectedContactNameChange: (String) -> Unit
    lateinit var onSelectedContactPhoneChange: (String) -> Unit
    lateinit var onSelectedContactSystemDialPhoneChange: (String) -> Unit
    lateinit var onSelectedContactHintChange: (String) -> Unit
    var directoryDetailPhone: String = ""
    lateinit var onDirectoryDetailPhoneChange: (String) -> Unit
    var directoryDetailInitial: com.vvtech.aiassistant.data.model.ContactDirectoryEntry? = null
    var directoryDetailSaving: Boolean = false
    var contactDirectoryLoading: Boolean = false
    var directoryDetailError: String? = null
    lateinit var onDirectoryDetailErrorChange: (String?) -> Unit
    lateinit var onCallContact: () -> Unit
    lateinit var onSaveDirectoryEntry: (ContactDirectoryUpsertRequest) -> Unit
    lateinit var onDeleteDirectoryEntry: (String) -> Unit
    var userIdentityPayload: UserIdentityPayload? = null
    var userIdentitySaving: Boolean = false
    var userIdentityLoading: Boolean = false
    var userIdentityError: String? = null
    lateinit var onUserIdentityErrorChange: (String?) -> Unit
    lateinit var onRefreshUserIdentity: () -> Unit
    lateinit var onSaveUserIdentity: (UserIdentityUpsertRequest) -> Unit
    lateinit var onDeleteUserIdentity: () -> Unit
    var contactMethods: List<PersonalInfoEntry> = emptyList()
    var selectedMethodId: String? = null
    lateinit var onSelectedMethodIdChange: (String?) -> Unit
    lateinit var onEditContactMethod: (PersonalInfoEntry) -> Unit
    lateinit var onApplyContactMethods: (List<PersonalInfoEntry>) -> Unit
    var editMode: String = ""
    var editingMethodId: String? = null
    var contactNameDraft: String = ""
    var contactGenderDraft: String = ""
    var contactPhoneDraft: String = ""
    var contactEditError: String? = null
    lateinit var onContactNameDraftChange: (String) -> Unit
    lateinit var onContactGenderDraftChange: (String) -> Unit
    lateinit var onContactPhoneDraftChange: (String) -> Unit
    lateinit var onContactEditErrorChange: (String?) -> Unit
    lateinit var onBeginAddContactMethod: () -> Unit
}

internal class CallPageArgs {
    var visibleCallRecords: List<FinalCallRecord> = emptyList()
    var selectedCallRecord: FinalCallRecord? = null
    var selectedRestaurantTitle: String? = null
    var aiCallSeconds: Int = 0
    var resultCallId: String = ""
    var resultAiModelInFlight: Boolean = false
    lateinit var onAiHangup: () -> Unit
    lateinit var onAiMonitorToggle: () -> Unit
    lateinit var onAiAudioRouteSelect: (CallMonitorAudioRoute) -> Unit
    lateinit var onBackResultHome: () -> Unit
    lateinit var onShareResult: () -> Unit
    lateinit var onAiModelCallContact: () -> Unit
    lateinit var onOpenCallRecord: (FinalCallRecord) -> Unit
    lateinit var onBackCallDetail: () -> Unit
    lateinit var onDialCallRecord: (FinalCallRecord) -> Unit
    lateinit var onReturnTaskFromCallDetail: (FinalCallRecord) -> Unit
    var lastDialedNumber: String = ""
    var dialInput: String = ""
    var normalCallSeconds: Int = 0
    var normalCallMuted: Boolean = false
    var normalCallSpeaker: Boolean = false
    var normalCallReturnPage: String = ""
    lateinit var onNormalMutedChange: (Boolean) -> Unit
    lateinit var onNormalSpeakerChange: (Boolean) -> Unit
    lateinit var onAppendCallRecord: (FinalCallRecord) -> Unit
    var translateCallSeconds: Int = 0
    var translationCallStatus: com.vvtech.aiassistant.core.model.TranslationCallStatusResponse? = null
    var translationCallError: String? = null
    var translationAudioChannelStatus: String? = null
    var translateCallMuted: Boolean = false
    var translateCallSpeaker: Boolean = false
    var translateCallPanelCollapsed: Boolean = false
    lateinit var onTranslateMuteToggle: () -> Unit
    lateinit var onTranslateSpeakerToggle: () -> Unit
    lateinit var onTranslatePanelToggle: () -> Unit
    lateinit var onTranslateHangup: () -> Unit
}

internal class TaskPageArgs {
    var visibleTaskRecords: List<FinalTaskRecord> = emptyList()
    var realTaskLoading: Boolean = false
    var conversationLoading: Boolean = false
    var realTaskError: String? = null
    var conversationError: String? = null
    var conversations: List<ConversationListItem> = emptyList()
    lateinit var onRefreshRealTasks: () -> Unit
}

internal class SettingsPageArgs {
    var developerModeEnabled: Boolean = false
    var appLanguage: AppLanguage = AppLanguage.English
    lateinit var onAppLanguageChange: (AppLanguage) -> Unit
    var selectedDomesticSipAccountId: String = ""
    var selectedInternationalSipAccountId: String = ""
    lateinit var onSelectDomesticSipAccount: (String) -> Unit
    lateinit var onSelectInternationalSipAccount: (String) -> Unit
    lateinit var onSelectedMethodReset: () -> Unit
    var selectedVoiceModelTitle: String = ""
    lateinit var onShowVoiceModelSheetChange: (Boolean) -> Unit
    lateinit var onOpenTrustedCalleeAuthorization: () -> Unit
    var otaUpdateChecking: Boolean = false
    lateinit var onCheckVersionUpdate: () -> Unit
    var logUploadInProgress: Boolean = false
    lateinit var onUploadLogs: () -> Unit
    lateinit var onShowLogoutConfirmChange: (Boolean) -> Unit
    lateinit var prefs: SharedPreferences
    var outboundNumber: String = ""
    var outboundDraft: String = ""
    var outboundError: String? = null
    var outboundLoading: Boolean = false
    var outboundConfigured: Boolean = false
    var outboundSaving: Boolean = false
    var outboundDeleting: Boolean = false
    lateinit var onOutboundDraftChange: (String) -> Unit
    lateinit var onOutboundErrorChange: (String?) -> Unit
    lateinit var onRefreshOutboundNumber: () -> Unit
    lateinit var onSaveOutboundNumber: () -> Unit
    lateinit var onDeleteOutboundNumber: () -> Unit
}

internal class ProviderSettingsArgs {
    var activeRealtimeProviderSummary: String = ""
    var realtimeProviderLoading: Boolean = false
    var realtimeProviderError: String? = null
    lateinit var onRefreshRealtimeProvider: (Boolean) -> Unit
    var activeTranslationProviderSummary: String = ""
    var translationProviderLoading: Boolean = false
    var translationProviderError: String? = null
    lateinit var onRefreshTranslationProvider: (Boolean) -> Unit
    var realtimeProviderResponse: RealtimeCallProviderResponse? = null
    var realtimeProviderSwitching: Boolean = false
    lateinit var onSwitchRealtimeCallProvider: (String) -> Unit
    var activeRealtimeCallVoiceSummary: String = ""
    var realtimeCallVoiceLoading: Boolean = false
    var realtimeCallVoiceError: String? = null
    var realtimeCallVoiceResponse: RealtimeCallVoiceResponse? = null
    var realtimeCallVoiceSwitching: Boolean = false
    lateinit var onRefreshRealtimeCallVoice: (Boolean) -> Unit
    lateinit var onSwitchRealtimeCallVoice: (String?, String) -> Unit
    var translationProviderResponse: RealtimeTranslationProviderResponse? = null
    var translationProviderSwitching: Boolean = false
    var translationQwenVoicePreference: String = ""
    lateinit var onTranslationQwenVoicePreferenceChange: (String) -> Unit
    lateinit var translationQwenLanguageSettings: TranslationProviderLanguageSettings
    lateinit var onTranslationQwenLanguageSettingsChange: (TranslationProviderLanguageSettings) -> Unit
    lateinit var onSwitchTranslationProvider: (String) -> Unit
}

internal class VoiceCloneArgs {
    var voiceCloneStatus: VoiceCloneStatusResponse? = null
    var voiceCloneLoading: Boolean = false
    var voiceCloneError: String? = null
    lateinit var onRefreshVoiceCloneStatus: () -> Unit
    var voiceCloneScripts: List<VoiceCloneScriptItem> = emptyList()
    var voiceCloneSamples: Map<String, VoiceCloneLocalSample> = emptyMap()
    var voiceCloneUploading: Boolean = false
    var voiceCloneActionLoading: Boolean = false
    var voiceCloneRecordingScriptId: String? = null
    lateinit var voiceCloneFace: com.vvtech.aiassistant.features.assistant_voice_clone.face.VoiceCloneFaceUiArgs
    lateinit var voiceCloneEnrollment: com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentUiArgs
    var voiceCloneSubmissionState: com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState =
        com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneSubmissionState.IDLE
    var voiceCloneCurrentScriptIndex: Int = 0
    lateinit var onSelectAiVoiceForCalls: () -> Unit
    lateinit var onSelectCloneVoiceForCalls: () -> Unit
    lateinit var onOpenVoiceCloneFlow: (Boolean) -> Unit
    lateinit var onVoiceCloneRecord: (VoiceCloneScriptItem) -> Unit
    lateinit var onVoiceCloneStop: (VoiceCloneScriptItem) -> Unit
    lateinit var onSubmitVoiceCloneRecording: () -> Unit
    lateinit var onVoiceCloneRerecord: () -> Unit
    lateinit var onStartUsingVoiceClone: (Boolean) -> Unit
    lateinit var onVoiceCloneLifecycleInterrupted: () -> Unit
}
internal class ConfirmClarifyArgs {
    var restaurantOptions: List<FinalOption> = emptyList()
    var fallbackOptions: List<FinalOption> = emptyList()
    var selectedRestaurantId: String? = null
    var selectedFallbackIds: MutableList<String> = mutableListOf()
    var requiredFallbackIds: MutableList<String> = mutableListOf()
    var restaurantConfirmed: Boolean = false
    var fallbackConfirmed: Boolean = false
    var confirmingRestaurantId: String? = null
    var confirmingFallbackId: String? = null
    lateinit var onSelectedRestaurantIdChange: (String?) -> Unit
    lateinit var onRestaurantConfirmedChange: (Boolean) -> Unit
    lateinit var onConfirmingRestaurantIdChange: (String?) -> Unit
    lateinit var onFallbackConfirmedChange: (Boolean) -> Unit
    lateinit var onConfirmingFallbackIdChange: (String?) -> Unit
    var selectedRestaurant: FinalOption? = null
    var selectedFallbacks: List<FinalOption> = emptyList()
    var defaultMethod: PersonalInfoEntry? = null
    var confirmAttachmentUploaded: Boolean = false
    lateinit var onConfirmAttachmentUploadedChange: (Boolean) -> Unit
    lateinit var blockIfOffline: () -> Boolean
    var storagePermissionGranted: Boolean = false
    lateinit var onRequestedPermissionNameChange: (String?) -> Unit
    lateinit var onPendingPermissionActionChange: (String) -> Unit
}
