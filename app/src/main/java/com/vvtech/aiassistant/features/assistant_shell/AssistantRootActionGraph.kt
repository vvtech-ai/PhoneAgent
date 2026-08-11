package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.*
import android.Manifest
import android.content.Context
import android.widget.Toast
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore

internal data class AssistantRootActionGraphDeps(
    val context: Context,
    val assistantViewModel: AssistantViewModel,
    val runtimeGraph: AssistantRootRuntimeGraph,
    val systemPhoneRuntime: AssistantRootSystemPhoneRuntime,
    val rootActivityLaunchers: AssistantRootActivityLaunchers,
    val voicePermissionLaunchers: AssistantVoicePermissionLaunchers,
    val contactPermissionLaunchers: AssistantContactPermissionLaunchers,
    val taskEntry: AssistantTaskEntryState,
    val homeNotification: AssistantHomeNotificationDerivedState
)

internal class AssistantRootActionGraph(
    private val deps: AssistantRootActionGraphDeps,
    val voiceEntry: AssistantVoiceEntryRootActions,
    val callEntry: AssistantRootCallEntryActions,
    val navigation: AssistantRootNavigationActions,
    val taskFlow: AssistantRootTaskFlowActions
) {
    fun blockIfOffline(): Boolean = blockAssistantRootIfOffline(deps)
    fun clearLocalTaskItemsForRequirementEntry() {
        clearAssistantRootLocalTaskItemsForRequirementEntry(deps.taskEntry)
    }

    fun clearPendingVoiceEntryState() {
        clearAssistantRootPendingVoiceEntryState(deps.runtimeGraph, deps.taskEntry)
    }

    fun hasMicrophonePermissionForVoiceEntry(): Boolean =
        voiceEntry.hasMicrophonePermissionForVoiceEntry()

    fun startVoiceInteractionWithPermission(
        forceNewTaskEntry: Boolean = false,
        useToggle: Boolean = false
    ) {
        voiceEntry.startVoiceInteractionWithPermission(forceNewTaskEntry, useToggle)
    }

    fun startVoiceEntry(
        initialCommand: String? = null,
        startWithVoice: Boolean = true,
        resumeExisting: Boolean =
            initialCommand.isNullOrBlank() && deps.assistantViewModel.agentSessionId != null,
        initialSkillId: String? = null,
        initialSkillOpening: String? = AgentInitialSkillLaunchStore.peekOpening(),
        selectedContact: SelectedContactTaskContext? = null
    ): Boolean = voiceEntry.startVoiceEntry(
        initialCommand = initialCommand,
        startWithVoice = startWithVoice,
        resumeExisting = resumeExisting,
        initialSkillId = initialSkillId,
        initialSkillOpening = initialSkillOpening,
        selectedContact = selectedContact
    )
}

internal fun clearAssistantRootLocalTaskItemsForRequirementEntry(
    taskEntry: AssistantTaskEntryState
) {
    taskEntry.clearLocalTaskItemsForRequirementEntry()
}

internal fun clearAssistantRootPendingVoiceEntryState(
    runtimeGraph: AssistantRootRuntimeGraph,
    taskEntry: AssistantTaskEntryState
) {
    taskEntry.clearPendingVoiceEntryState {
        runtimeGraph.runtime.voiceClone.showGuide = false
    }
}

internal fun buildAssistantRootActionGraph(
    deps: AssistantRootActionGraphDeps
): AssistantRootActionGraph {
    val state = deps.runtimeGraph.state
    val runtime = deps.runtimeGraph.runtime
    val navigationState = state.navigation
    val taskEntry = deps.taskEntry
    val assistantViewModel = deps.assistantViewModel
    val voiceEntryRootActions = AssistantVoiceEntryRootActions(
        deps = AssistantVoiceEntryRootActionDeps(
            context = deps.context,
            taskEntry = taskEntry,
            mockLoggedInProvider = { runtime.auth.mockLoggedIn },
            onMicrophonePermissionGrantedChange = {
                state.permissionOverlay.microphonePermissionGranted = it
            },
            onLaunchVoiceEntryPermission = {
                deps.voicePermissionLaunchers.voiceEntry.launch(Manifest.permission.RECORD_AUDIO)
            },
            onLaunchVoiceInteractionPermission = {
                deps.voicePermissionLaunchers.voiceInteraction.launch(Manifest.permission.RECORD_AUDIO)
            },
            onClearPendingVoiceEntryState = {
                clearAssistantRootPendingVoiceEntryState(deps.runtimeGraph, taskEntry)
            }
        ),
        flowCallbacks = AssistantVoiceEntryRootFlowCallbacks(
            onBlockOffline = { blockAssistantRootIfOffline(deps) },
            onBlockIdentityIncomplete = { false },
            onResetTaskConversationForNewEntry = assistantViewModel::resetTaskConversationForNewEntry,
            onClearLocalTaskItemsForRequirementEntry = {
                clearAssistantRootLocalTaskItemsForRequirementEntry(taskEntry)
            },
            onOpenExistingSingleFlow = {
                taskEntry.singleFlowForceNewVoiceEntryStart = false
                runtime.provider.refreshRealtimeCallProvider(force = true)
                navigationState.openAssistantSubPage(FinalPage.SingleFlow)
            },
            onOpenNewSingleFlow = { plan ->
                plan.initialSkillId?.let {
                    AgentInitialSkillLaunchStore.arm(it, plan.initialSkillOpening)
                }
                    ?: AgentInitialSkillLaunchStore.clear()
                taskEntry.singleFlowInitialCommand = plan.initialCommand
                taskEntry.singleFlowSelectedContact = plan.selectedContact
                taskEntry.singleFlowStartInVoice = plan.startInVoice
                taskEntry.singleFlowResumeListeningOnly = false
                taskEntry.singleFlowForceNewVoiceEntryStart = plan.forceNewVoiceEntryStart
                runtime.provider.refreshRealtimeCallProvider(force = true)
                taskEntry.bumpSingleFlowEntry()
                navigationState.openAssistantSubPage(FinalPage.SingleFlow)
            }
        ),
        dispatchCallbacks = AssistantVoiceEntryRootDispatchCallbacks(
            onToggleVoiceInput = assistantViewModel::toggleVoiceInputFromUser,
            onStartNewTaskEntry = assistantViewModel::startVoiceInteractionForNewTaskEntry,
            onApiMicClick = assistantViewModel::onApiMicClick
        )
    )
    val startVoiceEntry: (
        initialCommand: String?,
        startWithVoice: Boolean,
        resumeExisting: Boolean
    ) -> Unit = { initialCommand, startWithVoice, resumeExisting ->
        voiceEntryRootActions.startVoiceEntry(initialCommand, startWithVoice, resumeExisting)
    }
    val callEntryActions = AssistantRootCallEntryActions(
        AssistantRootCallEntryActionDeps(
            callDialState = state.callDial,
            clientCallController = runtime.clientCall,
            onStartTranslationCall = runtime.realtimeTranslation.launcher::start,
            permissionOverlayState = state.permissionOverlay,
            taskEntry = taskEntry,
            selectedContactSystemDialPhoneProvider = {
                runtime.contact.selectedContactSystemDialPhone
            },
            selectedContactNameProvider = { runtime.contact.selectedContactName },
            onLaunchSystemDialer = { target ->
                launchAssistantSystemDialer(
                    context = deps.context,
                    target = target,
                    onShowMessage = { message ->
                        Toast.makeText(deps.context, message, Toast.LENGTH_SHORT).show()
                    }
                )
            },
            translationProviderProvider = {
                runtime.provider.translationProviderResponse?.activeProvider ?: "QWEN_OMNI_PLUS"
            },
            selectedDomesticSipAccountIdProvider = {
                state.rootSettings.selectedDomesticSipAccountId
            },
            selectedInternationalSipAccountIdProvider = {
                state.rootSettings.selectedInternationalSipAccountId
            },
            onBlockOffline = { blockAssistantRootIfOffline(deps) },
            onHasMicrophonePermissionForVoiceEntry = voiceEntryRootActions::hasMicrophonePermissionForVoiceEntry,
            onLaunchTranslationAudioPermission = {
                deps.rootActivityLaunchers.translationCallAudioPermission.launch(
                    Manifest.permission.RECORD_AUDIO
                )
            },
            onEnableDeveloperMode = { state.rootSettings.enableDeveloperMode() },
            onShowDeveloperModeUnlocked = {
                Toast.makeText(deps.context, "已进入开发者模式", Toast.LENGTH_SHORT).show()
            },
            onApplyCallsMainTab = navigationState::applyCallsMainTab,
            onCloseHomeComposer = state.homeComposer::close,
            currentMainTabProvider = { navigationState.currentMainTab },
            currentPageProvider = { navigationState.currentPage },
            onShowMessage = { message ->
                Toast.makeText(deps.context, message, Toast.LENGTH_SHORT).show()
            }
        )
    )
    val rootNavigationActions = AssistantRootNavigationActions(
        AssistantRootNavigationActionDeps(
            state = AssistantRootNavigationStateProviders(
                currentMainTab = { navigationState.currentMainTab },
                currentPage = { navigationState.currentPage },
                previousMainTab = { navigationState.previousMainTab },
                pureVoiceMode = { state.rootSettings.pureVoiceMode },
                contactsPermissionGranted = { state.permissionOverlay.contactsPermissionGranted },
                taskStarted = { taskEntry.taskStarted }
            ),
            taskTab = AssistantRootNavigationTaskTabDeps(
                readState = state.homeNotificationRead,
                pendingNotificationsProvider = { deps.homeNotification.pendingHomeNotifications },
                onRefreshTasks = { runtime.task.refresh() },
                onLoadConversations = { assistantViewModel.loadConversations() }
            ),
            callbacks = AssistantRootNavigationActionCallbacks(
                onRequestContactsPermission = {
                    state.permissionOverlay.setPendingPermissionAction(
                        action = "open_contacts",
                        permissionName = V88PermissionKind.Contacts.name
                    )
                },
                onOpenCallsDialSheet = callEntryActions::openCallsDialSheet,
                onStartVoiceEntry = {
                    startVoiceEntry(null, true, assistantViewModel.agentSessionId != null)
                },
                onApplyMainTab = navigationState::applyMainTab,
                onHideCallsDialSheet = { state.callDial.hideDialSheet() },
                onCloseHomeComposer = state.homeComposer::close,
                shouldBlockAssistantEntry = { false },
                onApplySubPage = navigationState::applySubPage,
                onGoHome = { navigationState.goHome() }
            )
        )
    )
    val rootTaskFlowActions = AssistantRootTaskFlowActions(
        AssistantRootTaskFlowActionDeps(
            taskEntry = taskEntry,
            previousMainTabProvider = { navigationState.previousMainTab },
            currentPageProvider = { navigationState.currentPage },
            activeAccountIdProvider = { runtime.auth.activeAccountId },
            contactsPermissionGrantedProvider = { state.permissionOverlay.contactsPermissionGranted },
            shouldBlockOpenSingleFlow = { blockAssistantRootIfOffline(deps) },
            shouldBlockResumeSingleFlow = { false },
            onResetTaskConversationForNewEntry = assistantViewModel::resetTaskConversationForNewEntry,
            onClearLocalTaskItemsForRequirementEntry = {
                clearAssistantRootLocalTaskItemsForRequirementEntry(taskEntry)
            },
            onOpenSingleFlowPage = {
                runtime.provider.refreshRealtimeCallProvider(force = true)
                rootNavigationActions.openSubPage(FinalPage.SingleFlow)
            },
            onResumeSingleFlowPage = {
                runtime.provider.refreshRealtimeCallProvider(force = true)
                navigationState.resumeSubPage(FinalPage.SingleFlow)
            },
            onOpenAssistantPage = { navigationState.openAssistantPage(FinalPage.Assistant) },
            onShowHomeComposer = state.homeComposer::show,
            onSubmitTextTask = assistantViewModel::submitTextTask,
            onStartNewTextTask = { task ->
                startVoiceEntry(task, false, false)
            },
            onInterruptTaskConversationForUserClose = assistantViewModel::interruptTaskConversationForUserClose,
            onRestorePreviousMainTab = navigationState::restorePreviousMainTab,
            onCloseHomeComposer = state.homeComposer::close,
            onRefreshTasks = runtime.task::refresh,
            onLoadConversations = assistantViewModel::loadConversations,
            nextDeferredRefreshId = state.taskPageRefresh::nextDeferredRefreshId,
            onPauseTaskConversationAndResetLocalUi = { reason, reload ->
                AssistantHomeNotificationReadActions.dismissTaskForUserClose(
                    state.homeNotificationRead,
                    assistantViewModel.agentSessionId,
                    assistantViewModel.internalUiState.value.taskId
                )
                assistantViewModel.pauseTaskConversationAndResetLocalUi(reason, reload)
            },
            onApplyMainTab = navigationState::applyMainTab,
            onScheduleTaskRefreshAfterClose = runtime.task::scheduleRefreshAfterClose,
            onReturnToHomeFromResultPage = assistantViewModel::returnToHomeFromResultPage,
            onGoHome = { navigationState.goHome() },
            onApplyDeveloperDataMode = state.rootSettings::applyDeveloperDataMode,
            onClearCallRecordsForAccount = { accountId -> state.callRecord.clearForAccount(accountId) },
            onApplyContactDeveloperDataMode = runtime.contact::applyDeveloperDataModeContactState
        )
    )
    return AssistantRootActionGraph(
        deps = deps,
        voiceEntry = voiceEntryRootActions,
        callEntry = callEntryActions,
        navigation = rootNavigationActions,
        taskFlow = rootTaskFlowActions
    )
}
