package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.NonRestartableComposable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.vvtech.aiassistant.features.assistant_shell.*
@Composable
@NonRestartableComposable
fun AssistantRootScreen(
    assistantViewModel: AssistantViewModel
) {
    val assistantUiState by assistantViewModel.uiState.collectAsStateWithLifecycle()
    val conversations by assistantViewModel.conversationList.collectAsStateWithLifecycle()
    val conversationLoading by assistantViewModel.conversationLoading.collectAsStateWithLifecycle()
    val conversationError by assistantViewModel.conversationError.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val rootUserMessages = rememberAssistantRootUserMessageActions(context)
    val rootRuntimeGraph = rememberAssistantRootRuntimeGraph(
        context = context,
        assistantViewModel = assistantViewModel
    )
    val prefs = rootRuntimeGraph.environment.prefs
    val scope = rootRuntimeGraph.environment.scope
    val selectedVoiceModelId = rootRuntimeGraph.environment.selectedVoiceModelId
    val navigationState = rootRuntimeGraph.state.navigation
    val transientOverlayState = rootRuntimeGraph.state.transientOverlay
    val taskPageRefreshState = rootRuntimeGraph.state.taskPageRefresh
    val homeNotificationReadState = rootRuntimeGraph.state.homeNotificationRead
    val permissionOverlayState = rootRuntimeGraph.state.permissionOverlay
    val systemPhoneCallState = rootRuntimeGraph.state.systemPhoneCall
    val homeComposerState = rootRuntimeGraph.state.homeComposer
    val rootSettingsState = rootRuntimeGraph.state.rootSettings
    val callRecordState = rootRuntimeGraph.state.callRecord
    val callDialState = rootRuntimeGraph.state.callDial
    val voiceCloneRuntime = rootRuntimeGraph.runtime.voiceClone
    val providerRuntime = rootRuntimeGraph.runtime.provider
    val authRuntime = rootRuntimeGraph.runtime.auth
    val otaRuntime = rootRuntimeGraph.runtime.ota
    val logUploadRuntime = rootRuntimeGraph.runtime.logUpload
    val outboundRuntime = rootRuntimeGraph.runtime.outbound
    val taskRuntime = rootRuntimeGraph.runtime.task
    val contactRuntime = rootRuntimeGraph.runtime.contact
    val contactAiModelRuntime = rootRuntimeGraph.runtime.contactAiModel
    val clientCallRuntime = rootRuntimeGraph.runtime.clientCall
    val clientCallState by clientCallRuntime.state.collectAsStateWithLifecycle()
    val realtimeTranslationRuntime = rootRuntimeGraph.runtime.realtimeTranslation
    val realtimeTranslationState by realtimeTranslationRuntime.coordinator.state.collectAsStateWithLifecycle()
    val translationRuntime = rootRuntimeGraph.runtime.translation
    var currentMainTab by navigationState::currentMainTab
    var currentPage by navigationState::currentPage
    val pureVoiceMode = rootSettingsState.pureVoiceMode
    val voiceLanguage = rootSettingsState.voiceLanguage
    val networkMode = permissionOverlayState.networkMode
    val requestedPermission = permissionOverlayState.requestedPermission
    AssistantRootPrimaryShellEffects(
        AssistantRootPrimaryShellEffectsArgs(
            context = context,
            lifecycleOwner = lifecycleOwner,
            assistantViewModel = assistantViewModel,
            rootRuntimeGraph = rootRuntimeGraph
        )
    )
    val taskEntry = rememberAssistantTaskEntryState()
    val taskEntryOptions = deriveAssistantTaskEntryOptions(
        AssistantTaskEntryOptionsInput(
            selectedRestaurantId = taskEntry.selectedRestaurantId,
            selectedFallbackIds = taskEntry.selectedFallbackIds
        )
    )
    val selectedRestaurant = taskEntryOptions.selectedRestaurant
    val localCallRecords = callRecordState.records
    val localTaskRecords = taskRuntime.records.toList()
    val homeNotificationDerivedState = rememberAssistantHomeNotificationRuntimeState(
        AssistantHomeNotificationRuntimeInput(
            currentPage = currentPage,
            currentMainTab = currentMainTab,
            backendHistoryRecords = assistantUiState.historyRecords,
            localCallRecords = localCallRecords,
            taskRecords = localTaskRecords,
            conversations = conversations,
            readState = homeNotificationReadState
        )
    )
    AssistantTaskDeferredRefreshShellEffect(
        AssistantTaskDeferredRefreshShellEffectArgs(
            taskPageEnteredSignal = taskPageRefreshState.taskPageEnteredSignal,
            pendingDeferredTaskRefreshCloseId = taskRuntime.pendingDeferredRefreshCloseId,
            currentPage = currentPage,
            currentMainTab = currentMainTab,
            onClearPendingDeferredTaskRefreshCloseId = taskRuntime::clearPendingDeferredRefreshCloseId,
            onRefreshTasks = { reason -> taskRuntime.refresh(reason = reason) },
            onLoadConversations = { reason -> assistantViewModel.loadConversations(reason = reason) }
        )
    )
    AssistantOtaRuntimeShellEffects(
        lifecycleOwner = lifecycleOwner,
        runtime = otaRuntime
    )
    bindAssistantRootAuthResetSessionCallback(
        AssistantRootAuthResetCallbackBindingArgs(
            rootRuntimeGraph = rootRuntimeGraph,
            taskEntry = taskEntry,
            onResetTaskConversationForNewEntry = assistantViewModel::resetTaskConversationForNewEntry,
            onSetIdentityInitOverlayVisible = assistantViewModel::setIdentityInitOverlayVisible
        )
    )
    val systemPhoneRuntime = rememberAssistantRootDialSystemPhoneCoordinator(
        context = context,
        callDialState = callDialState,
        permissionOverlayState = permissionOverlayState,
        systemPhoneCallState = systemPhoneCallState,
        callRecordState = callRecordState,
        activeAccountId = { authRuntime.activeAccountId },
        clearTranslationRuntime = { translationRuntime.clearRuntimeState(stopAudioSocket = true) },
        onPermissionDenied = rootUserMessages::showSystemPhonePermissionDenied
    )
    val permissionRuntime = rememberAssistantRootPermissionRuntime(
        deps = AssistantRootPermissionRuntimeDeps(
            context = context,
            scope = scope,
            assistantUiState = assistantUiState,
            taskEntry = taskEntry,
            permissionOverlayState = permissionOverlayState,
            transientOverlayState = transientOverlayState,
            contactRuntime = contactRuntime,
            navigationState = navigationState,
            assistantViewModel = assistantViewModel,
            mockLoggedInProvider = { authRuntime.mockLoggedIn }
        ),
        callbacks = AssistantRootPermissionRuntimeCallbacks(
            onVoiceCloneAudioPermissionResult = voiceCloneRuntime::onRecordAudioPermissionResult,
            onTranslationAudioPermissionGranted = translationRuntime::onAudioPermissionGranted,
            onShowMessage = rootUserMessages::showMessage,
            onLoadLocationIfPermitted = assistantViewModel::loadLocationIfPermitted,
            onTrustedCalleeStartupReadyChange = { authRuntime.trustedCalleeStartupReady = it },
            onClearPendingVoiceEntryState = {
                clearAssistantRootPendingVoiceEntryState(rootRuntimeGraph, taskEntry)
            },
            log = ::logAssistantRootWarning
        )
    )
    val rootActivityLaunchers = permissionRuntime.rootActivityLaunchers
    val voicePermissionLaunchers = permissionRuntime.voicePermissionLaunchers
    val contactPermissionLaunchers = permissionRuntime.contactPermissionLaunchers
    if (FinalAuthGate(authRuntime)) {
        return
    }
    AssistantRootSecondaryShellEffects(
        AssistantRootSecondaryShellEffectsArgs(
            context = context,
            prefs = prefs,
            assistantUiState = assistantUiState,
            assistantViewModel = assistantViewModel,
            rootRuntimeGraph = rootRuntimeGraph,
            rootActivityLaunchers = rootActivityLaunchers,
            lifecycleOwner = lifecycleOwner
        )
    )
    val rootActionGraph = buildAssistantRootActionGraph(
        AssistantRootActionGraphDeps(
            context = context,
            assistantViewModel = assistantViewModel,
            runtimeGraph = rootRuntimeGraph,
            systemPhoneRuntime = systemPhoneRuntime,
            rootActivityLaunchers = rootActivityLaunchers,
            voicePermissionLaunchers = voicePermissionLaunchers,
            contactPermissionLaunchers = contactPermissionLaunchers,
            taskEntry = taskEntry,
            homeNotification = homeNotificationDerivedState
        )
    )
    val voiceEntryRootActions = rootActionGraph.voiceEntry
    val callEntryActions = rootActionGraph.callEntry
    val rootNavigationActions = rootActionGraph.navigation
    val rootTaskFlowActions = rootActionGraph.taskFlow
    AssistantRootPostActionShellEffects(
        AssistantRootPostActionShellEffectsArgs(
            currentPage = currentPage,
            assistantUiState = assistantUiState,
            taskEntry = taskEntry,
            rootRuntimeGraph = rootRuntimeGraph,
            rootActionGraph = rootActionGraph
        )
    )
    var singleFlowTransitionContentCount by remember { mutableStateOf(0) }
    val pageHostDerivedState = deriveAssistantPageHostState(
        AssistantPageHostDerivedStateInput(
            currentPage = currentPage,
            assistantUiState = assistantUiState,
            localTaskStarted = taskEntry.taskStarted,
            localTaskUserText = taskEntry.taskUserText,
            localAiThinking = taskEntry.aiThinking,
            localAiReplyVisible = taskEntry.aiReplyVisible,
            useSingleFlowConversation = UseSingleFlowConversationInFinal,
            resultCallIdFallback = assistantRootResultCallIdFallback(),
            singleFlowTransitionContentVisible =
                pureVoiceMode && singleFlowTransitionContentCount > 0
        )
    )
    val hostArgs = buildAssistantRootHostArgs(
        AssistantRootHostArgsFactoryDeps(
            context = context,
            prefs = prefs,
            assistantViewModel = assistantViewModel,
            assistantUiState = assistantUiState,
            state = AssistantRootHostStateDeps(
                settings = rootSettingsState,
                taskEntry = taskEntry,
                permissionOverlay = permissionOverlayState,
                transientOverlay = transientOverlayState,
                homeComposer = homeComposerState,
                pageHost = pageHostDerivedState,
                homeNotification = homeNotificationDerivedState,
                homeNotificationRead = homeNotificationReadState,
                callDial = callDialState
            ),
            runtime = AssistantRootHostRuntimeDeps(
                auth = authRuntime,
                contact = contactRuntime,
                contactAiModel = contactAiModelRuntime,
                outbound = outboundRuntime,
                provider = providerRuntime,
                ota = otaRuntime,
                logUpload = logUploadRuntime,
                voiceClone = voiceCloneRuntime,
                task = taskRuntime,
                clientCall = clientCallRuntime,
                clientCallState = clientCallState,
                realtimeTranslation = realtimeTranslationRuntime,
                realtimeTranslationState = realtimeTranslationState,
                translation = translationRuntime,
                callRecord = callRecordState
            ),
            launchers = AssistantRootHostLauncherDeps(
                rootActivity = rootActivityLaunchers,
                contactPermission = contactPermissionLaunchers
            ),
            actions = AssistantRootHostActionDeps(
                taskFlow = rootTaskFlowActions,
                callEntry = callEntryActions,
                voiceEntry = voiceEntryRootActions
            ),
            values = AssistantRootHostValueDeps(
                selectedVoiceModelId = selectedVoiceModelId,
                taskEntryOptions = taskEntryOptions,
                pureVoiceMode = pureVoiceMode,
                voiceLanguage = voiceLanguage,
                appLanguage = rootSettingsState.appLanguage,
                selectedRestaurant = selectedRestaurant,
                activeAccountId = authRuntime.activeAccountId,
                conversationLoading = conversationLoading,
                conversationError = conversationError,
                conversations = conversations
            ),
            page = AssistantRootHostPageDeps(
                currentPage = currentPage,
                currentMainTab = currentMainTab,
                networkMode = networkMode,
                requestedPermission = requestedPermission
            ),
            navigation = AssistantRootHostNavigationCallbacks(
                onPageChange = navigationState::navigateTo,
                onMainTabChange = navigationState::setMainTab,
                onTaskPageEntered = taskPageRefreshState::markTaskPageEntered,
                onOpenSubPage = rootNavigationActions::openSubPage,
                onBackToMainTab = rootNavigationActions::backToMainTab,
                onSwitchMainTab = rootNavigationActions::switchMainTab,
                onGoHomeAfterContactsDenied = { navigationState.goHome(resetPrevious = false) },
                onAiHangupReturnAssistant = {
                    navigationState.setMainTab(FinalMainTab.Assistant)
                }
            ),
            entry = AssistantRootHostEntryCallbacks(
                blockIfOffline = rootActionGraph::blockIfOffline,
                onQuickVoiceEntry = { initialSkillId ->
                    rootActionGraph.startVoiceEntry(
                        startWithVoice = true,
                        resumeExisting = false,
                        initialSkillId = initialSkillId
                    )
                },
                onStartVoiceEntry = {
                    rootActionGraph.startVoiceEntry(startWithVoice = true, resumeExisting = false)
                },
                onStartVoiceInteractionWithPermission = { forceNewTaskEntry, useToggle ->
                    rootActionGraph.startVoiceInteractionWithPermission(
                        forceNewTaskEntry = forceNewTaskEntry,
                        useToggle = useToggle
                    )
                }
            )
        )
    )
    PhoneFrameWithBackground {
        AssistantPageBackdropHost(hostArgs.overlayHost) {
            AssistantPageHost(hostArgs.pageHost) { page, visible ->
                if (page == FinalPage.SingleFlow) {
                    val delta = if (visible) 1 else -1
                    singleFlowTransitionContentCount =
                        (singleFlowTransitionContentCount + delta).coerceAtLeast(0)
                }
            }
        }
        AssistantOverlayHost(hostArgs.overlayHost)
    }
}
