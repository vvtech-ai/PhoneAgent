package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.*
import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.model.ConversationListItem

internal data class AssistantRootPageHostMainArgs(
    val navigation: PageHostNavigationArgs,
    val contact: ContactPageArgs,
    val call: CallPageArgs,
    val task: TaskPageArgs
)

internal data class AssistantRootPageHostMainArgsFactoryDeps(
    val assistantViewModel: AssistantViewModel,
    val state: AssistantRootPageHostMainStateDeps,
    val runtime: AssistantRootPageHostMainRuntimeDeps,
    val actions: AssistantRootPageHostMainActionDeps,
    val values: AssistantRootPageHostMainValueDeps,
    val callbacks: AssistantRootPageHostMainCallbacks
)

internal data class AssistantRootPageHostMainStateDeps(
    val pageHost: AssistantPageHostDerivedState,
    val homeNotification: AssistantHomeNotificationDerivedState,
    val taskEntry: AssistantTaskEntryState,
    val callDial: AssistantCallDialState
)

internal data class AssistantRootPageHostMainRuntimeDeps(
    val contact: AssistantContactRuntimeController,
    val contactAiModel: AssistantContactAiModelRuntimeController,
    val task: AssistantTaskRuntimeController,
    val translation: AssistantTranslationCallRuntimeController,
    val callRecord: AssistantCallRecordState,
    val provider: AssistantProviderRuntimeController
)

internal data class AssistantRootPageHostMainActionDeps(
    val taskFlow: AssistantRootTaskFlowActions,
    val callEntry: AssistantRootCallEntryActions,
    val onStartContactSkill: (String, SelectedContactTaskContext) -> Boolean
)

internal data class AssistantRootPageHostMainValueDeps(
    val currentPage: FinalPage,
    val voiceLanguage: VoiceLanguage,
    val appLanguage: AppLanguage,
    val selectedRestaurant: FinalOption?,
    val activeAccountId: String,
    val pureVoiceMode: Boolean,
    val conversationLoading: Boolean,
    val conversationError: String?,
    val conversations: List<ConversationListItem>
)

internal data class AssistantRootPageHostMainCallbacks(
    val onPageChange: (FinalPage) -> Unit,
    val onMainTabChange: (FinalMainTab) -> Unit,
    val onTaskPageEntered: () -> Unit,
    val onOpenSubPage: (FinalPage) -> Unit,
    val onBackToMainTab: () -> Unit,
    val onShareResult: () -> Unit
)

internal fun buildAssistantRootPageHostMainArgs(
    deps: AssistantRootPageHostMainArgsFactoryDeps
): AssistantRootPageHostMainArgs =
    AssistantRootPageHostMainArgs(
        navigation = buildAssistantPageHostNavigationArgs(deps.navigationInput()),
        contact = buildAssistantContactArgs(deps.contactInput()),
        call = buildAssistantCallArgs(deps.callInput()),
        task = buildAssistantTaskPageArgs(deps.taskInput())
    )

private fun AssistantRootPageHostMainArgsFactoryDeps.navigationInput() =
    AssistantPageHostNavigationInput(
        state = AssistantPageHostNavigationState(
            pageBottomInset = state.pageHost.pageBottomInset,
            currentPage = values.currentPage
        ),
        callbacks = AssistantPageHostNavigationCallbacks(
            onPageChange = callbacks.onPageChange,
            onMainTabChange = callbacks.onMainTabChange,
            onTaskPageEntered = callbacks.onTaskPageEntered,
            onOpenSubPage = callbacks.onOpenSubPage,
            onOpenSingleFlow = { initialCommand, startWithVoice ->
                actions.taskFlow.openSingleFlow(
                    initialCommand = initialCommand.ifBlank { null },
                    startWithVoice = startWithVoice
                )
            },
            onStartContactSkill = { skillId, contactName, contactPhone ->
                actions.onStartContactSkill(
                    skillId,
                    SelectedContactTaskContext.contactDetail(
                        name = contactName,
                        phone = contactPhone
                    )
                )
            },
            onOpenMyIdentityVoiceModelSettings = {
                runtime.provider.refreshRealtimeCallProvider(force = true)
                callbacks.onOpenSubPage(FinalPage.RealtimeProviderSettings)
            },
            onOpenSingleFlowDefault = { actions.taskFlow.openSingleFlow() },
            onResumeSingleFlow = { startListening ->
                actions.taskFlow.resumeSingleFlow(startListening = startListening)
            },
            onPauseTaskFlowAndReturnToPreviousTab = { source ->
                actions.taskFlow.pauseTaskFlowAndReturnToPreviousTab(source = source)
            },
            onRestartSingleFlow = actions.taskFlow::restartSingleFlow,
            onGoHomePreservingSession = actions.taskFlow::goHomePreservingSession,
            onBackToMainTab = callbacks.onBackToMainTab
        )
    )

private fun AssistantRootPageHostMainArgsFactoryDeps.contactInput(): AssistantContactArgsBuilderInput =
    runtime.contact.buildArgsInput(
        voiceLanguage = values.voiceLanguage,
        externalCallbacks = AssistantContactRuntimeExternalCallbacks(
            onCallContact = actions.callEntry::openDialFromContact
        )
    )

private fun AssistantRootPageHostMainArgsFactoryDeps.callInput() =
    AssistantCallArgsBuilderInput(
        ai = AssistantCallAiInput(
            visibleCallRecords = state.homeNotification.visibleCallRecords,
            selectedCallRecord = runtime.callRecord.selectedRecord,
            selectedRestaurantTitle = values.selectedRestaurant?.title,
            aiCallSeconds = state.taskEntry.aiCallSeconds,
            resultCallId = state.pageHost.resultCallId,
            resultAiModelInFlight = runtime.contactAiModel.inFlight
        ),
        normal = AssistantNormalCallInput(
            lastDialedNumber = state.callDial.dialer.lastDialedNumber,
            dialInput = state.callDial.dialer.dialInput,
            normalCallSeconds = state.callDial.normalCallSeconds,
            normalCallMuted = state.callDial.normalCallMuted,
            normalCallSpeaker = state.callDial.normalCallSpeaker,
            normalCallReturnPage = state.callDial.normalCallReturnPage
        ),
        callbacks = AssistantCallCallbacksInput(
            onAiHangup = {
                assistantViewModel.hangUpCall(
                    onFinished = {
                        callbacks.onPageChange(
                            if (values.pureVoiceMode) FinalPage.SingleFlow else FinalPage.Assistant
                        )
                    }
                )
            },
            onAiMonitorToggle = assistantViewModel::toggleCallMonitor,
            onAiAudioRouteSelect = assistantViewModel::selectCallMonitorAudioRoute,
            onBackResultHome = actions.taskFlow::returnResultToHome,
            onShareResult = callbacks.onShareResult,
            onAiModelCallContact = { runtime.contactAiModel.modelCallContact(state.pageHost.resultCallId) },
            onOpenCallRecord = { record ->
                runtime.callRecord.selectRecord(record)
                callbacks.onPageChange(FinalPage.AgentCallDetail)
            },
            onBackCallDetail = {
                runtime.callRecord.clearSelectedRecord()
                callbacks.onPageChange(FinalPage.Calls)
            },
            onDialCallRecord = { record ->
                actions.callEntry.runNormalCallToNumber(record.phoneNumber)
            },
            onReturnTaskFromCallDetail = { record ->
                runtime.callRecord.clearSelectedRecord()
                val taskId = record.taskId.trim()
                if (taskId.isNotBlank()) {
                    assistantViewModel.resumeConversation(taskId) {
                        actions.taskFlow.resumeSingleFlow(startListening = false)
                    }
                } else {
                    actions.taskFlow.resumeSingleFlow(startListening = false)
                }
            },
            onNormalMutedChange = { state.callDial.normalCallMuted = it },
            onNormalSpeakerChange = { state.callDial.normalCallSpeaker = it },
            onAppendCallRecord = { runtime.callRecord.appendForAccount(values.activeAccountId, it) },
            onApplyTranslationCallArgs = { runtime.translation.applyToCallPageArgs(it) }
        )
    )

private fun AssistantRootPageHostMainArgsFactoryDeps.taskInput() =
    AssistantTaskPageArgsBuilderInput(
        visibleTaskRecords = state.homeNotification.visibleTaskRecords,
        realTaskLoading = runtime.task.loading,
        conversationLoading = values.conversationLoading,
        realTaskError = runtime.task.error,
        conversationError = values.conversationError,
        conversations = values.conversations,
        onRefreshRealTasks = { runtime.task.refresh() }
    )
