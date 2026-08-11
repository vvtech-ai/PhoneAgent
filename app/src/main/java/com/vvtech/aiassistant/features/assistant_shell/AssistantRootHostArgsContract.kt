package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import android.content.SharedPreferences
import com.vvtech.aiassistant.callengine.AssistantClientCallController
import com.vvtech.aiassistant.callengine.AssistantClientCallState
import com.vvtech.aiassistant.features.app_logs.AssistantLogUploadRuntimeController
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState
import com.vvtech.aiassistant.model.ConversationListItem

internal data class AssistantRootHostArgs(
    val pageHost: AssistantPageHostArgs,
    val overlayHost: AssistantOverlayHostArgs
)

internal data class AssistantRootHostArgsFactoryDeps(
    val context: Context,
    val prefs: SharedPreferences,
    val assistantViewModel: AssistantViewModel,
    val assistantUiState: Index9AssistantUiState,
    val state: AssistantRootHostStateDeps,
    val runtime: AssistantRootHostRuntimeDeps,
    val launchers: AssistantRootHostLauncherDeps,
    val actions: AssistantRootHostActionDeps,
    val values: AssistantRootHostValueDeps,
    val page: AssistantRootHostPageDeps,
    val navigation: AssistantRootHostNavigationCallbacks,
    val entry: AssistantRootHostEntryCallbacks
)

internal data class AssistantRootHostStateDeps(
    val settings: AssistantRootSettingsPreferenceState,
    val taskEntry: AssistantTaskEntryState,
    val permissionOverlay: AssistantPermissionOverlayState,
    val transientOverlay: AssistantRootTransientOverlayState,
    val homeComposer: AssistantHomeComposerState,
    val pageHost: AssistantPageHostDerivedState,
    val homeNotification: AssistantHomeNotificationDerivedState,
    val homeNotificationRead: AssistantHomeNotificationReadState,
    val callDial: AssistantCallDialState
)

internal data class AssistantRootHostRuntimeDeps(
    val auth: AssistantAuthRuntimeController,
    val contact: AssistantContactRuntimeController,
    val contactAiModel: AssistantContactAiModelRuntimeController,
    val outbound: AssistantOutboundNumberRuntimeController,
    val provider: AssistantProviderRuntimeController,
    val ota: AssistantOtaRuntimeController,
    val logUpload: AssistantLogUploadRuntimeController,
    val voiceClone: AssistantVoiceCloneRuntimeController,
    val task: AssistantTaskRuntimeController,
    val clientCall: AssistantClientCallController,
    val clientCallState: AssistantClientCallState,
    val realtimeTranslation: AssistantRealtimeTranslationRuntime,
    val realtimeTranslationState: TranslationCallUiState,
    val translation: AssistantTranslationCallRuntimeController,
    val callRecord: AssistantCallRecordState
)

internal data class AssistantRootHostLauncherDeps(
    val rootActivity: AssistantRootActivityLaunchers,
    val contactPermission: AssistantContactPermissionLaunchers
)

internal data class AssistantRootHostActionDeps(
    val taskFlow: AssistantRootTaskFlowActions,
    val callEntry: AssistantRootCallEntryActions,
    val voiceEntry: AssistantVoiceEntryRootActions
)

internal data class AssistantRootHostValueDeps(
    val selectedVoiceModelId: String,
    val taskEntryOptions: AssistantTaskEntryOptionsState,
    val pureVoiceMode: Boolean,
    val voiceLanguage: VoiceLanguage,
    val selectedRestaurant: FinalOption?,
    val activeAccountId: String,
    val conversationLoading: Boolean,
    val conversationError: String?,
    val conversations: List<ConversationListItem>
)

internal data class AssistantRootHostPageDeps(
    val currentPage: FinalPage,
    val currentMainTab: FinalMainTab,
    val networkMode: V88NetworkMode,
    val requestedPermission: V88PermissionKind?
)

internal data class AssistantRootHostNavigationCallbacks(
    val onPageChange: (FinalPage) -> Unit,
    val onMainTabChange: (FinalMainTab) -> Unit,
    val onTaskPageEntered: () -> Unit,
    val onOpenSubPage: (FinalPage) -> Unit,
    val onBackToMainTab: () -> Unit,
    val onSwitchMainTab: (FinalMainTab) -> Unit,
    val onGoHomeAfterContactsDenied: () -> Unit,
    val onAiHangupReturnAssistant: () -> Unit
)

internal data class AssistantRootHostEntryCallbacks(
    val blockIfOffline: () -> Boolean,
    val onQuickVoiceEntry: (String?) -> Boolean,
    val onStartVoiceEntry: () -> Unit,
    val onStartVoiceInteractionWithPermission: (forceNewTaskEntry: Boolean, useToggle: Boolean) -> Unit
)
