package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import com.vvtech.aiassistant.callengine.AssistantClientCallController
import com.vvtech.aiassistant.data.repository.AssistantContainer
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneEnrollmentRepository
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.network.NetworkModule
import com.vvtech.aiassistant.features.app_logs.AssistantLogUploadRuntimeController
import com.vvtech.aiassistant.features.app_logs.AssistantLogUploadRuntimeDeps
import com.vvtech.aiassistant.features.app_logs.rememberAssistantLogUploadRuntimeController
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.assistant_calls.dialTranslationLanguageCodes
import com.vvtech.aiassistant.features.assistant_calls.rememberAssistantDialerStateHolder
import com.vvtech.aiassistant.features.assistant_calls.TranslationCallOrigin
import com.vvtech.aiassistant.features.assistant_translation.rememberAssistantTranslationCallRuntimeController
import com.vvtech.aiassistant.repository.AppContainer
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope

internal data class AssistantRootRuntimeGraph(
    val environment: AssistantRootRuntimeEnvironment,
    val state: AssistantRootStateGraph,
    val runtime: AssistantRootControllerGraph
)

internal data class AssistantRootRuntimeEnvironment(
    val prefs: SharedPreferences,
    val scope: CoroutineScope,
    val repositories: AssistantRootRepositoryGraph,
    val authResetSessionCallback: Array<(String) -> Unit>,
    val selectedVoiceModelId: String
)

internal data class AssistantRootRepositoryGraph(
    val task: TaskRepository,
    val assistant: AssistantRepository,
    val voiceCloneEnrollment: VoiceCloneEnrollmentRepository
)

internal data class AssistantRootStateGraph(
    val navigation: AssistantNavigationState,
    val transientOverlay: AssistantRootTransientOverlayState,
    val taskPageRefresh: AssistantTaskPageRefreshState,
    val homeNotificationRead: AssistantHomeNotificationReadState,
    val permissionOverlay: AssistantPermissionOverlayState,
    val systemPhoneCall: AssistantSystemPhoneCallState,
    val homeComposer: AssistantHomeComposerState,
    val rootSettings: AssistantRootSettingsPreferenceState,
    val callRecord: AssistantCallRecordState,
    val callDial: AssistantCallDialState
)

internal data class AssistantRootControllerGraph(
    val voiceClone: AssistantVoiceCloneRuntimeController,
    val provider: AssistantProviderRuntimeController,
    val auth: AssistantAuthRuntimeController,
    val ota: AssistantOtaRuntimeController,
    val logUpload: AssistantLogUploadRuntimeController,
    val outbound: AssistantOutboundNumberRuntimeController,
    val task: AssistantTaskRuntimeController,
    val contact: AssistantContactRuntimeController,
    val contactAiModel: AssistantContactAiModelRuntimeController,
    val clientCall: AssistantClientCallController,
    val realtimeTranslation: AssistantRealtimeTranslationRuntime,
    val translation: AssistantTranslationCallRuntimeController
)

@Composable
internal fun rememberAssistantRootRuntimeGraph(
    context: Context,
    assistantViewModel: AssistantViewModel
): AssistantRootRuntimeGraph {
    val prefs = remember(context) { context.getSharedPreferences(FinalPrefsName, Context.MODE_PRIVATE) }
    val scope = rememberCoroutineScope()
    val repositories = AssistantRootRepositoryGraph(
        task = remember { AppContainer.taskRepository },
        assistant = remember { AssistantContainer.repository },
        voiceCloneEnrollment = remember {
            VoiceCloneEnrollmentRepository(NetworkModule.voiceCloneVerificationApi)
        }
    )
    val navigationState = rememberAssistantNavigationState()
    val transientOverlayState = rememberAssistantRootTransientOverlayState()
    val taskPageRefreshState = rememberAssistantTaskPageRefreshState()
    val authResetSessionCallback = remember { arrayOf<(String) -> Unit>({}) }
    val rootSettingsState = rememberAssistantRootSettingsPreferenceState(prefs)
    val permissionOverlayState = rememberAssistantPermissionOverlayState(context)
    val systemPhoneCallState = rememberAssistantSystemPhoneCallState()
    val homeComposerState = rememberAssistantHomeComposerState(ComposerMode.Voice.name)
    val homeNotificationReadState = rememberAssistantHomeNotificationReadState(prefs)
    val callRecordState = rememberAssistantCallRecordState(prefs)
    val dialerState = rememberAssistantDialerStateHolder(prefs)
    val callDialState = rememberAssistantCallDialState(
        normalCallReturnPageDefault = FinalPage.Calls.name,
        dialer = dialerState
    )
    val refreshCallVoiceCallback = remember { arrayOf<() -> Unit>({}) }
    val refreshIdentityCallback = remember { arrayOf<() -> Unit>({}) }

    val voiceCloneRuntime = rememberAssistantVoiceCloneRuntimeController(
        context = context,
        prefs = prefs,
        scope = scope,
        taskRepository = repositories.task,
        enrollmentRepository = repositories.voiceCloneEnrollment,
        identityPrefillLoader = {
            loadVoiceCloneIdentityPrefill(
                AccountIdentityProvider.accountId,
                repositories.assistant::getUserIdentity
            )
        },
        onIdentityVerified = { refreshIdentityCallback[0]() },
        callbacks = AssistantVoiceCloneRuntimeCallbacks(
            onOpenVoiceCloneSettings = {
                navigationState.applySubPage(
                    navigationState.currentMainTab,
                    FinalPage.VoiceCloneSettings
                )
            },
            onOpenVoiceIdentitySettings = {
                refreshCallVoiceCallback[0]()
                navigationState.navigateTo(FinalPage.RealtimeCallVoiceSettings)
            }
        )
    )
    val providerRuntime = rememberAssistantProviderRuntimeController(
        deps = AssistantProviderRuntimeDeps(
            context = context,
            taskRepository = repositories.task,
            scope = scope
        ),
        callbacks = AssistantProviderRuntimeCallbacks(
            onRealtimeProviderChanged = voiceCloneRuntime::onRealtimeProviderChanged,
            onRealtimeCallVoiceChanged = voiceCloneRuntime::refreshStatus
        )
    )
    refreshCallVoiceCallback[0] = { providerRuntime.refreshRealtimeCallVoice(force = true) }
    val authRuntime = rememberAssistantAuthRuntimeController(
        deps = AssistantAuthRuntimeDeps(
            context = context,
            prefs = prefs,
            taskRepository = repositories.task,
            scope = scope
        ),
        callbacks = AssistantAuthRuntimeCallbacks(
            onResetSession = { reason -> authResetSessionCallback[0](reason) }
        )
    )
    val callRuntimes = rememberAssistantCallRuntimeControllers(
        context = context,
        callRecordState = callRecordState,
        authRuntime = authRuntime,
        navigationState = navigationState,
        callDialState = callDialState
    )
    val otaRuntime = rememberAssistantOtaRuntimeController(
        AssistantOtaRuntimeDeps(context, prefs, repositories.task, scope)
    )
    val logUploadRuntime = rememberAssistantLogUploadRuntimeController(
        AssistantLogUploadRuntimeDeps(context, repositories.task, scope)
    )
    val outboundRuntime = rememberAssistantOutboundNumberRuntimeController(
        deps = AssistantOutboundNumberRuntimeDeps(
            context = context,
            taskRepository = repositories.task,
            scope = scope
        ),
        callbacks = AssistantOutboundNumberRuntimeCallbacks(
            onNavigateToDeveloperTools = { navigationState.navigateTo(FinalPage.DeveloperTools) }
        )
    )
    val taskRuntime = rememberAssistantTaskRuntimeController(
        AssistantTaskRuntimeDeps(
            assistantRepository = repositories.assistant,
            taskRepository = repositories.task,
            scope = scope
        )
    )
    val contactRuntime = rememberAssistantContactRuntimeController(
        deps = AssistantContactRuntimeDeps(
            context = context,
            prefs = prefs,
            repository = repositories.assistant,
            scope = scope
        ),
        callbacks = AssistantContactRuntimeCallbacks(
            onContactsPermissionGrantedChange = { permissionOverlayState.contactsPermissionGranted = it },
            onPageChange = navigationState::navigateTo,
            onOpenContactMethodEdit = {
                openAssistantSubPageWithPolicy(
                    page = FinalPage.ContactMethodEdit,
                    state = AssistantSubPageOpenState(
                        pureVoiceMode = rootSettingsState.pureVoiceMode,
                        currentMainTab = navigationState.currentMainTab
                    ),
                    callbacks = AssistantSubPageOpenCallbacks(
                        shouldBlockAssistantEntry = { false },
                        onApplySubPage = navigationState::applySubPage
                    )
                )
            },
            onIdentityOverlaySaved = { assistantViewModel.setIdentityInitOverlayVisible(false) },
            onIdentityInitOverlayVisibleChange = assistantViewModel::setIdentityInitOverlayVisible
        )
    )
    refreshIdentityCallback[0] = contactRuntime::refreshUserIdentity
    val contactAiModelRuntime = rememberAssistantContactAiModelRuntimeController(
        context = context,
        scope = scope,
        callbacks = AssistantContactAiModelRuntimeCallbacks(
            onModeledContactCreated = contactRuntime::refreshContactDirectory
        )
    )
    val translationRuntime = rememberAssistantTranslationCallRuntimeController(
        context = context,
        deps = AssistantTranslationCallRuntimeDeps(
            repository = repositories.assistant,
            scope = scope
        ),
        callbacks = AssistantTranslationCallRuntimeCallbacks(
            dialInput = { callDialState.dialer.dialInput },
            onDialInputChange = { callDialState.dialer.dialInput = it },
            lastDialedNumber = { callDialState.dialer.lastDialedNumber },
            onLastDialedNumberChange = { callDialState.dialer.lastDialedNumber = it },
            onShowCallsDialSheetChange = { callDialState.showCallsDialSheet = it },
            translationProvider = { providerRuntime.translationProviderResponse?.activeProvider },
            translationQwenVoicePreference = { rootSettingsState.translationQwenVoicePreference },
            translationQwenLanguageSettings = {
                val languages = dialTranslationLanguageCodes(
                    myLanguage = callDialState.dialer.myLanguage,
                    otherLanguage = callDialState.dialer.otherLanguage
                )
                TranslationProviderLanguageSettings(
                    callerLanguage = languages.caller,
                    calleeLanguage = languages.callee
                )
            },
            onAppendCallRecordIfAbsent = {
                callRecordState.appendIfAbsentForAccount(authRuntime.activeAccountId, it)
            },
            onNavigateToTranslateCall = { navigationState.navigateTo(FinalPage.TranslateCall) },
            onNavigateAfterExit = { origin ->
                if (origin == TranslationCallOrigin.DIALER) {
                    navigationState.restoreDialDestination(callDialState.returnDestination)
                    callDialState.openDialSheet()
                } else {
                    navigationState.applyMainTab(FinalMainTab.Calls)
                }
            },
            dialTarget = callDialState.dialer::fullDialNumber
        )
    )
    val selectedVoiceModelId = remember(providerRuntime.realtimeProviderResponse) {
        val activeModelId = providerRuntime.realtimeProviderResponse?.activeProvider?.toV88VoiceModelId()
        V88VoiceModelOptions.firstOrNull { it.id == activeModelId && it.enabled }?.id
            ?: defaultV88VoiceModelOption().id
    }

    return AssistantRootRuntimeGraph(
        environment = AssistantRootRuntimeEnvironment(
            prefs = prefs,
            scope = scope,
            repositories = repositories,
            authResetSessionCallback = authResetSessionCallback,
            selectedVoiceModelId = selectedVoiceModelId
        ),
        state = AssistantRootStateGraph(
            navigation = navigationState,
            transientOverlay = transientOverlayState,
            taskPageRefresh = taskPageRefreshState,
            homeNotificationRead = homeNotificationReadState,
            permissionOverlay = permissionOverlayState,
            systemPhoneCall = systemPhoneCallState,
            homeComposer = homeComposerState,
            rootSettings = rootSettingsState,
            callRecord = callRecordState,
            callDial = callDialState
        ),
        runtime = AssistantRootControllerGraph(
            voiceClone = voiceCloneRuntime,
            provider = providerRuntime,
            auth = authRuntime,
            ota = otaRuntime,
            logUpload = logUploadRuntime,
            outbound = outboundRuntime,
            task = taskRuntime,
            contact = contactRuntime,
            contactAiModel = contactAiModelRuntime,
            clientCall = callRuntimes.clientCall,
            realtimeTranslation = callRuntimes.realtimeTranslation,
            translation = translationRuntime
        )
    )
}
