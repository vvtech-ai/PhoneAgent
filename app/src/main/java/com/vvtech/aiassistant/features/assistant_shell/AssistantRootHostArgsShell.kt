package com.vvtech.aiassistant.features.assistant_shell
import android.Manifest
import android.widget.Toast
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_pure_voice.buildPureVoicePrecheckUiState
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.features.assistant.toV88VoiceModelOptions
internal fun buildAssistantRootHostArgs(deps: AssistantRootHostArgsFactoryDeps): AssistantRootHostArgs {
    val pageHostSecondaryArgs = deps.secondaryArgs()
    val pageHostAssistantArgs = deps.assistantArgs()
    val pageHostMainArgs = deps.mainArgs()
    val pageHostArgs = buildAssistantPageHostArgs(
        AssistantPageHostArgsBuilderInput(
            navigation = pageHostMainArgs.navigation,
            assistant = pageHostAssistantArgs,
            contact = pageHostMainArgs.contact,
            call = pageHostMainArgs.call,
            task = pageHostMainArgs.task,
            settings = pageHostSecondaryArgs.settings,
            providerSettings = pageHostSecondaryArgs.providerSettings,
            voiceClone = pageHostSecondaryArgs.voiceClone,
            confirmClarify = pageHostSecondaryArgs.confirmClarify,
            permissionDeveloper = pageHostSecondaryArgs.permissionDeveloper
        )
    )
    return AssistantRootHostArgs(
        pageHost = pageHostArgs,
        overlayHost = deps.overlayArgs()
    )
}
private fun AssistantRootHostArgsFactoryDeps.secondaryArgs(): AssistantRootPageHostSecondaryArgs =
    buildAssistantRootPageHostSecondaryArgs(
        AssistantRootPageHostSecondaryArgsFactoryDeps(
            context = context,
            prefs = prefs,
            runtime = AssistantRootPageHostSecondaryRuntimeDeps(
                auth = runtime.auth,
                contact = runtime.contact,
                outbound = runtime.outbound,
                provider = runtime.provider,
                ota = runtime.ota,
                logUpload = runtime.logUpload,
                voiceClone = runtime.voiceClone
            ),
            state = AssistantRootPageHostSecondaryStateDeps(
                settings = state.settings,
                taskEntry = state.taskEntry,
                permissionOverlay = state.permissionOverlay,
                transientOverlay = state.transientOverlay,
                taskFlowActions = actions.taskFlow
            ),
            launchers = launchers.rootActivity,
            values = AssistantRootPageHostSecondaryValueDeps(
                selectedVoiceModelId = values.selectedVoiceModelId,
                taskEntryOptions = values.taskEntryOptions
            ),
            callbacks = AssistantRootPageHostSecondaryCallbacks(
                blockIfOffline = entry.blockIfOffline,
                onResetDialerLocationPermissionAndOpenDialSheet = {
                    state.callDial.dialer.locationPromptShown = false
                    state.callDial.dialer.locationSystemPermissionRequested = false
                    actions.callEntry.openCallsDialSheet(selectTranslate = true)
                }
            )
        )
    )
private fun AssistantRootHostArgsFactoryDeps.assistantArgs(): AssistantPageArgs =
    buildAssistantRootPageHostAssistantArgs(
        AssistantRootPageHostAssistantArgsFactoryDeps(
            assistantViewModel = assistantViewModel,
            assistantUiState = assistantUiState,
            state = AssistantRootPageHostAssistantStateDeps(
                homeComposer = state.homeComposer,
                taskEntry = state.taskEntry,
                pageHost = state.pageHost,
                homeNotification = state.homeNotification,
                homeNotificationRead = state.homeNotificationRead
            ),
            actions = AssistantRootPageHostAssistantActionDeps(
                taskFlow = actions.taskFlow,
                callEntry = actions.callEntry,
                contact = runtime.contact,
                agentDocumentPicker = agentDocumentPickerCallbacks()
            ),
            values = AssistantRootPageHostAssistantValueDeps(
                pureVoiceMode = values.pureVoiceMode,
                pureVoicePrecheck = buildPureVoicePrecheckUiState(
                    networkMode = page.networkMode,
                    providerLoading = runtime.provider.realtimeProviderLoading,
                    providerError = runtime.provider.realtimeProviderError,
                    providerResponse = runtime.provider.realtimeProviderResponse
                ),
                activeCallModelTitle = runtime.provider.activeRealtimeProviderSummary.ifBlank {
                    AssistantCallModelDisplayNames.Qwen
                }
            ),
            callbacks = AssistantRootPageHostAssistantCallbacks(
                onQuickVoiceEntry = entry.onQuickVoiceEntry, onBlockOffline = entry.blockIfOffline,
                onStartVoiceEntry = entry.onStartVoiceEntry,
                onStartVoiceInteractionWithPermission = entry.onStartVoiceInteractionWithPermission,
                onSwitchMainTab = navigation.onSwitchMainTab,
                onOpenCallModelSheet = {
                    runtime.provider.refreshRealtimeCallProvider(true)
                    state.transientOverlay.setVoiceModelSheetVisible(true)
                }
            )
        )
    )
private fun AssistantRootHostArgsFactoryDeps.mainArgs(): AssistantRootPageHostMainArgs =
    buildAssistantRootPageHostMainArgs(
        AssistantRootPageHostMainArgsFactoryDeps(
            assistantViewModel = assistantViewModel,
            state = AssistantRootPageHostMainStateDeps(
                pageHost = state.pageHost,
                homeNotification = state.homeNotification,
                taskEntry = state.taskEntry,
                callDial = state.callDial
            ),
            runtime = AssistantRootPageHostMainRuntimeDeps(
                contact = runtime.contact,
                contactAiModel = runtime.contactAiModel,
                task = runtime.task,
                translation = runtime.translation,
                callRecord = runtime.callRecord,
                provider = runtime.provider
            ),
            actions = AssistantRootPageHostMainActionDeps(
                taskFlow = actions.taskFlow,
                callEntry = actions.callEntry, onStartContactSkill = actions::startContactSkill
            ),
            values = AssistantRootPageHostMainValueDeps(
                currentPage = page.currentPage,
                voiceLanguage = values.voiceLanguage,
                appLanguage = values.appLanguage,
                selectedRestaurant = values.selectedRestaurant,
                activeAccountId = values.activeAccountId,
                pureVoiceMode = values.pureVoiceMode,
                conversationLoading = values.conversationLoading,
                conversationError = values.conversationError,
                conversations = values.conversations
            ),
            callbacks = AssistantRootPageHostMainCallbacks(
                onPageChange = navigation.onPageChange,
                onMainTabChange = navigation.onMainTabChange,
                onTaskPageEntered = navigation.onTaskPageEntered,
                onOpenSubPage = navigation.onOpenSubPage,
                onBackToMainTab = navigation.onBackToMainTab,
                onShareResult = { showMessage(currentAppText("分享功能待接入", "Sharing is coming soon")) }
            )
        )
    )
private fun AssistantRootHostArgsFactoryDeps.overlayArgs(): AssistantOverlayHostArgs =
    buildAssistantRootOverlayArgs(
        AssistantRootOverlayArgsFactoryDeps(
            navigation = AssistantRootOverlayNavigationDeps(
                showBottomTabs = state.pageHost.showBottomTabs,
                currentMainTab = page.currentMainTab,
                onSelectMainTab = navigation.onSwitchMainTab,
                assistantNavHidden = state.pageHost.assistantNavHidden,
                taskBadgeCount = state.homeNotification.taskBadgeCount,
                pureVoiceMode = values.pureVoiceMode,
                currentPage = page.currentPage,
                appLanguage = values.appLanguage
            ),
            aiCall = AssistantRootOverlayAiCallDeps(
                selectedRestaurantTitle = values.selectedRestaurant?.title,
                activeCallModelTitle = runtime.provider.activeRealtimeProviderSummary.ifBlank {
                    AssistantCallModelDisplayNames.Qwen
                },
                assistantUiState = assistantUiState,
                aiCallSeconds = state.taskEntry.aiCallSeconds,
                onAiHangup = { assistantViewModel.hangUpCall(navigation.onAiHangupReturnAssistant) },
                onAiMonitorToggle = assistantViewModel::toggleCallMonitor,
                onAiAudioRouteSelect = assistantViewModel::selectCallMonitorAudioRoute
            ),
            dial = buildAssistantRootOverlayDialDeps(this, ::showMessage),
            permission = permissionDeps(),
            guide = guideDeps(),
            model = modelDeps(),
            account = accountDeps()
        )
    ).also { args ->
        args.activeTranslationProviderTitle =
            runtime.realtimeTranslation.selectedProviderTitle
        args.activeTranslationProvider =
            runtime.realtimeTranslation.selectedProviderId
        args.availableTranslationProviders =
            runtime.realtimeTranslation.availableProviderIds
        args.translationModelQuality =
            runtime.realtimeTranslation.modelQuality
        args.onRefreshTranslationModelQuality =
            runtime.realtimeTranslation::refreshModelQuality
        args.onSelectTranslationProvider =
            runtime.realtimeTranslation::selectProvider
        args.voiceModelLatencySource =
            runtime.provider.callModelLatencySource
        args.translationCallState = runtime.realtimeTranslationState
        args.onTranslationCallAction = runtime.realtimeTranslation.coordinator::dispatch
        args.onTranslationCallTick = runtime.realtimeTranslation.coordinator::tick
    }
private fun AssistantRootHostArgsFactoryDeps.permissionDeps(): AssistantRootOverlayPermissionDeps =
    AssistantRootOverlayPermissionDeps(
        state = AssistantRootOverlayPermissionState(
            networkMode = page.networkMode,
            showNetworkBlocker = state.permissionOverlay.showNetworkBlocker,
            requestedPermission = page.requestedPermission
        ),
        callbacks = AssistantRootOverlayPermissionCallbacks(
            onShowMessage = ::showMessage,
            onShowNetworkBlockerChange = { state.permissionOverlay.showNetworkBlocker = it },
            onRequestedPermissionNameChange = { state.permissionOverlay.requestedPermissionName = it },
            onPendingPermissionActionChange = { state.permissionOverlay.pendingPermissionAction = it },
            onMicrophonePermissionGrantedChange = { state.permissionOverlay.microphonePermissionGranted = it },
            onStoragePermissionGrantedChange = { state.permissionOverlay.storagePermissionGranted = it },
            onContactsPermissionGrantedChange = { state.permissionOverlay.contactsPermissionGranted = it },
            onPhonePermissionGrantedChange = { state.permissionOverlay.phonePermissionGranted = it },
            onLaunchContactsPermission = {
                launchers.contactPermission.contacts.launch(Manifest.permission.READ_CONTACTS)
            },
            onRunPendingPermissionAction = actions.callEntry::runPendingPermissionAction,
            onGoHomeAfterContactsDenied = navigation.onGoHomeAfterContactsDenied,
            onDismissNetworkBlocker = state.permissionOverlay::dismissNetworkBlocker
        )
    )
private fun AssistantRootHostArgsFactoryDeps.guideDeps(): AssistantRootOverlayGuideDeps =
    AssistantRootOverlayGuideDeps(
        showVoiceCloneGuide = runtime.voiceClone.showGuide,
        onStartVoiceCloneGuide = runtime.voiceClone::startGuide,
        onDismissVoiceCloneGuide = {
            runtime.voiceClone.dismissGuide()
            actions.voiceEntry.openPendingVoiceEntry()
        },
        onNeverAskVoiceCloneGuide = {
            runtime.voiceClone.neverAskGuide()
            actions.voiceEntry.openPendingVoiceEntry()
        },
        onApplyTrustedCalleeOverlayArgs = runtime.auth::applyTrustedCalleeOverlayArgs
    )
private fun AssistantRootHostArgsFactoryDeps.modelDeps(): AssistantRootOverlayModelDeps =
    AssistantRootOverlayModelDeps(
        state = AssistantRootOverlayModelState(
            showVoiceModelSheet = state.transientOverlay.showVoiceModelSheet,
            selectedVoiceModelId = values.selectedVoiceModelId,
            availableVoiceModelIds = runtime.provider.realtimeProviderResponse
                ?.providers
                ?.filter { it.available }
                ?.map { it.provider }
                ?.toSet()
                .orEmpty(),
            voiceModelOptions = resolveV88VoiceModelOptions(runtime.provider.realtimeProviderResponse),
            realtimeProviderSwitching = runtime.provider.realtimeProviderSwitching
        ),
        callbacks = AssistantRootOverlayModelCallbacks(
            onShowMessage = ::showMessage,
            onShowVoiceModelSheetChange = state.transientOverlay::setVoiceModelSheetVisible,
            onSwitchRealtimeCallProvider = runtime.provider::switchRealtimeCallProvider,
            onCloseVoiceModelSheet = state.transientOverlay::hideVoiceModelSheet
        )
    )
private fun AssistantRootHostArgsFactoryDeps.accountDeps(): AssistantRootOverlayAccountDeps =
    AssistantRootOverlayAccountDeps(
        onApplyOtaOverlayArgs = runtime.ota::applyOverlayArgs,
        onApplyLogoutOverlayArgs = runtime.auth::applyLogoutOverlayArgs,
        identityOverlaySaving = runtime.contact.identityOverlaySaving,
        identityOverlayError = runtime.contact.identityOverlayError,
        identityCompletionOnly = runtime.contact.identityCompletionOnly,
        initialIdentity = runtime.contact.userIdentityPayload,
        initialTranslationProvider = runtime.realtimeTranslation.domesticProviderId,
        onDismissIdentityOverlay = {
            val completionOnly = runtime.contact.identityCompletionOnly
            runtime.contact.dismissIdentityInitOverlay()
            if (completionOnly) {
                actions.voiceEntry.cancelPendingVoiceEntry()
            }
        },
        onSkipIdentityForSession = {
            runtime.contact.skipInitialIdentityForSession()
        },
        onSubmitIdentityOverlay = { request ->
            runtime.contact.saveUserIdentityFromOverlay(request) {
                runtime.contact.dismissIdentityInitOverlay()
                actions.voiceEntry.continueVoiceEntryAfterIdentityCompleted()
            }
        },
        onSelectInitializationCallProvider = runtime.provider::switchRealtimeCallProvider,
        onSelectInitializationTranslationProvider = { provider ->
            runtime.realtimeTranslation.selectDomesticProvider(provider)
            runtime.provider.switchTranslationProvider(provider)
        },
        onAgentDeviceContactSelectionConfirm = assistantViewModel::onAgentDeviceContactSelectionConfirm,
        onAgentDeviceContactSelectionCancel = assistantViewModel::onAgentDeviceContactSelectionCancel
    )
private fun AssistantRootHostArgsFactoryDeps.agentDocumentPickerCallbacks() =
    AssistantAgentDocumentPickerCallbacks(
        onUpdateActiveAgentDocumentRequest = state.transientOverlay::updateActiveAgentDocumentRequest,
        onClearAgentDocumentRequest = state.transientOverlay::clearAgentDocumentRequest,
        onLaunchDocumentPicker = { mimeTypes -> launchers.rootActivity.agentDocument.launch(mimeTypes) },
        onAgentDocumentPickerCancelled = assistantViewModel::onAgentDocumentPickerCancelled,
        onShowMessage = ::showMessage
    )
private fun AssistantRootHostArgsFactoryDeps.showMessage(message: String) =
    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
