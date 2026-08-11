package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState
import kotlinx.coroutines.flow.update

internal data class AssistantRootPageHostAssistantArgsFactoryDeps(
    val assistantViewModel: AssistantViewModel,
    val assistantUiState: Index9AssistantUiState,
    val state: AssistantRootPageHostAssistantStateDeps,
    val actions: AssistantRootPageHostAssistantActionDeps,
    val values: AssistantRootPageHostAssistantValueDeps,
    val callbacks: AssistantRootPageHostAssistantCallbacks
)

internal data class AssistantRootPageHostAssistantStateDeps(
    val homeComposer: AssistantHomeComposerState,
    val taskEntry: AssistantTaskEntryState,
    val pageHost: AssistantPageHostDerivedState,
    val homeNotification: AssistantHomeNotificationDerivedState,
    val homeNotificationRead: AssistantHomeNotificationReadState
)

internal data class AssistantRootPageHostAssistantActionDeps(
    val taskFlow: AssistantRootTaskFlowActions,
    val callEntry: AssistantRootCallEntryActions,
    val contact: AssistantContactRuntimeController,
    val agentDocumentPicker: AssistantAgentDocumentPickerCallbacks
)

internal data class AssistantRootPageHostAssistantValueDeps(
    val pureVoiceMode: Boolean,
    val pureVoicePrecheck: PureVoicePrecheckUiState?,
    val activeCallModelTitle: String
)

internal data class AssistantRootPageHostAssistantCallbacks(
    val onQuickVoiceEntry: (String?) -> Boolean,
    val onBlockOffline: () -> Boolean,
    val onStartVoiceEntry: () -> Unit,
    val onStartVoiceInteractionWithPermission: (forceNewTaskEntry: Boolean, useToggle: Boolean) -> Unit,
    val onSwitchMainTab: (FinalMainTab) -> Unit,
    val onOpenCallModelSheet: () -> Unit
)

internal fun buildAssistantRootPageHostAssistantArgs(
    deps: AssistantRootPageHostAssistantArgsFactoryDeps
): AssistantPageArgs =
    buildAssistantConversationArgs(
        AssistantConversationArgsBuilderInput(
            core = deps.coreInput(),
            callbacks = deps.callbacksInput(),
            agent = deps.agentInput(),
            notification = deps.notificationInput(),
            singleFlow = deps.singleFlowInput()
        )
    )

private fun AssistantRootPageHostAssistantArgsFactoryDeps.coreInput() =
    AssistantConversationCoreInput(
        assistantViewModel = assistantViewModel,
        assistantUiState = assistantUiState,
        homeComposerOpen = state.homeComposer.isOpen,
        effectiveTaskStarted = state.pageHost.effectiveTaskStarted,
        effectiveTaskUserText = state.pageHost.effectiveTaskUserText,
        effectiveAiThinking = state.pageHost.effectiveAiThinking,
        effectiveAiReplyVisible = state.pageHost.effectiveAiReplyVisible,
        taskTextDraft = state.taskEntry.taskTextDraft,
        pureVoiceMode = values.pureVoiceMode,
        pureVoicePrecheck = if (values.pureVoiceMode) values.pureVoicePrecheck else null,
        composerMode = state.homeComposer.modeName
    )

private fun AssistantRootPageHostAssistantArgsFactoryDeps.callbacksInput() =
    AssistantConversationCallbacksInput(
        onHomeComposerOpenChange = { state.homeComposer.isOpen = it },
        onTaskTextDraftChange = { state.taskEntry.taskTextDraft = it },
        onComposerModeChange = state.homeComposer::updateModeName,
        onQuickVoiceEntry = callbacks.onQuickVoiceEntry,
        onOpenTranslateDial = { actions.callEntry.openCallsDialSheet(selectTranslate = true) },
        onBlockHomeCardIfOffline = callbacks.onBlockOffline,
        activeCallModelTitle = values.activeCallModelTitle,
        onOpenCallModelSheet = callbacks.onOpenCallModelSheet,
        onStartVoice = callbacks.onStartVoiceEntry,
        onStopVoice = assistantViewModel::stopApiListening,
        onInterruptTts = assistantViewModel::onTtsInterrupted,
        onSendText = actions.taskFlow::submitTextTaskFlow,
        onStopTask = actions.taskFlow::resetTaskFlow,
        onPersistTaskContactIfNeeded = actions.contact::persistTaskContactIfNeeded
    )

private fun AssistantRootPageHostAssistantArgsFactoryDeps.agentInput() =
    AssistantConversationAgentInput(
        onAgentDocumentSelect = {
            launchAssistantAgentDocumentPicker(
                request = assistantUiState.agentDocumentRequest,
                callbacks = actions.agentDocumentPicker
            )
        },
        onAgentDocumentCancel = {
            cancelAssistantAgentDocumentPicker(actions.agentDocumentPicker)
        },
        onAgentSheetDismiss = {
            assistantViewModel.internalUiState.update {
                it.copy(agentQuestions = null, agentOptions = null)
            }
        },
        onReplayTts = { text ->
            assistantViewModel.ttsBridge.feedSignalText(text)
        }
    )

private fun AssistantRootPageHostAssistantArgsFactoryDeps.notificationInput() =
    AssistantConversationNotificationInput(
        homeNotificationVisible = state.homeNotification.homeNotificationVisible,
        homeNotificationText = state.homeNotification.homeNotificationText,
        homeNotificationExtra = state.homeNotification.homeNotificationExtra,
        homeNotificationStatusKind = state.homeNotification.homeNotificationStatusKind,
        onClickHomeNotification = { callbacks.onSwitchMainTab(FinalMainTab.Tasks) },
        onDismissHomeNotification = {
            AssistantHomeNotificationReadActions.dismissCurrent(
                readState = state.homeNotificationRead,
                currentNotification = state.homeNotification.currentHomeNotification
            )
        }
    )

private fun AssistantRootPageHostAssistantArgsFactoryDeps.singleFlowInput() =
    AssistantConversationSingleFlowInput(
        singleFlowInitialCommand = state.taskEntry.singleFlowInitialCommand,
        onConsumeSingleFlowSelectedContact = state.taskEntry::consumeSingleFlowSelectedContact,
        singleFlowStartInVoice = state.taskEntry.singleFlowStartInVoice,
        singleFlowResumeListeningOnly = state.taskEntry.singleFlowResumeListeningOnly,
        singleFlowEntryKey = state.taskEntry.singleFlowEntryKey,
        singleFlowForceNewVoiceEntryStart = state.taskEntry.singleFlowForceNewVoiceEntryStart,
        onStartVoiceInteractionWithPermission = callbacks.onStartVoiceInteractionWithPermission
    )
