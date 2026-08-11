package com.vvtech.aiassistant.features.assistant_lifecycle

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheStore
import com.vvtech.aiassistant.data.repository.ocr.ConversationOcrAttachmentRepository
import com.vvtech.aiassistant.data.repository.timeline.AppFileTimelineSyncLogger
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineRepository
import com.vvtech.aiassistant.data.repository.timeline.RetrofitConversationTimelineRemoteSource
import com.vvtech.aiassistant.network.NetworkModule
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceDuplexCoordinator
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.VoiceRuntimeHandler
import com.vvtech.aiassistant.features.assistant.localizedListeningStatus
import com.vvtech.aiassistant.features.assistant.localizedReconnectingVoiceStatus
import com.vvtech.aiassistant.features.assistant.localizedTapMicToContinueStatus
import com.vvtech.aiassistant.features.assistant_agent.AgentStreamHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUserContextHolder
import com.vvtech.aiassistant.features.assistant.viewmodel.CallActionHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.ConversationStateHolder
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultUserId
import com.vvtech.aiassistant.features.assistant.viewmodel.DetailSupplementActionHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.LocalPromptActionHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.LocalPromptCallbacks
import com.vvtech.aiassistant.features.assistant.viewmodel.LocalPromptDeps
import com.vvtech.aiassistant.features.assistant.viewmodel.VoiceEntryActionHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.localizedContactLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.localizedDetailLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.localizedTaskReadyStatus
import com.vvtech.aiassistant.features.assistant_actions.AssistantAgentDocumentActionHandler
import com.vvtech.aiassistant.features.assistant_actions.AssistantUserDecisionActionHandler
import com.vvtech.aiassistant.features.assistant_audio.AssistantOutboundCallAudioGate
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrAttachmentHandler
import com.vvtech.aiassistant.features.assistant_session.*
import com.vvtech.aiassistant.features.assistant_tasks.AssistantTaskConversationLifecycleCallbacks
import com.vvtech.aiassistant.features.assistant_tasks.AssistantTaskConversationLifecycleDeps
import com.vvtech.aiassistant.features.assistant_tasks.AssistantTaskConversationLifecycleHandler
import com.vvtech.aiassistant.features.assistant_tasks.AssistantTaskConversationLifecycleStateAccess
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallHistoryController
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallHistoryControllerDeps
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallHistoryUiStateHolder
import com.vvtech.aiassistant.features.assistant_tasks.TaskConversationBackgroundPauseStateHolder
import com.vvtech.aiassistant.features.assistant_tasks.TaskConversationExitResetStateReader
import com.vvtech.aiassistant.features.assistant_tasks.TaskConversationInterruptUseCase
import com.vvtech.aiassistant.features.assistant_tasks.TaskConversationListLoadStateHolder
import com.vvtech.aiassistant.features.assistant_tasks.TaskConversationListLoadUseCase
import com.vvtech.aiassistant.features.assistant_tasks.TaskErrorRecoveryHolder
import com.vvtech.aiassistant.features.assistant_tasks.TaskRestoreStateHolder
import com.vvtech.aiassistant.features.assistant_voice.VoiceRecoverableTurnCoordinator

internal class AssistantViewModelHandlerGraph(
    private val viewModel: AssistantViewModel
) {
    val conversationStateHolder = ConversationStateHolder(viewModel.internalUiState)
    val taskRestoreStateHolder = TaskRestoreStateHolder(viewModel.conversationList)
    private val timelineRepository = ConversationTimelineRepository(
        remote = RetrofitConversationTimelineRemoteSource(NetworkModule.conversationTimelineApi),
        cache = TimelineCacheStore(viewModel.appContext),
        logger = AppFileTimelineSyncLogger(),
    )
    val voiceRecoverableTurnCoordinator = VoiceRecoverableTurnCoordinator(
        timelineRepository = timelineRepository,
        accountIdProvider = { AccountIdentityProvider.accountId },
        log = viewModel::internalLog,
    )

    val conversationRestoreHandler = ConversationRestoreHandler(
        deps = RestoreHandlerDeps(
            restoreUseCase = AssistantConversationRestoreUseCase(
                repository = viewModel.repository,
                timelineRepository = timelineRepository,
                accountIdProvider = { AccountIdentityProvider.accountId },
                log = viewModel::internalLog,
            ),
            uiState = viewModel.internalUiState,
            conversationList = viewModel.conversationList,
            taskRestoreStateHolder = taskRestoreStateHolder,
            scope = viewModel.viewModelScope
        ),
        callbacks = RestoreCallbacks(
            setAgentSessionId = { viewModel.agentSessionId = it },
            idleStatus = { DefaultIdleStatus },
            localizedListeningStatus = { viewModel.localizedListeningStatus() },
            localizedTapMicToContinueStatus = { viewModel.localizedTapMicToContinueStatus() },
            log = viewModel::internalLog
        )
    )

    val userContextHolder = AssistantUserContextHolder(
        appContext = viewModel.appContext,
        uiState = viewModel.internalUiState,
        scope = viewModel.viewModelScope,
        log = viewModel::internalLog
    )
    val pureVoiceOcrAttachmentHandler by lazy {
        PureVoiceOcrAttachmentHandler(
            context = viewModel.appContext,
            repository = ConversationOcrAttachmentRepository(
                NetworkModule.conversationOcrAttachmentApi
            ),
        )
    }

    val conversationSubmitActionHandler = ConversationSubmitActionHandler(
        viewModel = viewModel,
        conversationStateHolder = conversationStateHolder
    )
    val detailSupplementActionHandler = DetailSupplementActionHandler(viewModel)
    val taskErrorRecoveryHolder = TaskErrorRecoveryHolder(
        appContext = viewModel.appContext,
        repository = viewModel.repository,
        uiState = viewModel.internalUiState,
        conversationList = viewModel.conversationList,
        scope = viewModel.viewModelScope,
        currentAgentSessionId = { viewModel.agentSessionId },
        pendingAiCallLaunch = { viewModel.pendingAiCallLaunch },
        currentVoiceLanguage = viewModel::currentVoiceLanguage,
        cancelTextProcessingStatusProgress = viewModel::cancelTextProcessingStatusProgress,
        closeTaskVoiceRealtime = viewModel::closeTaskVoiceRealtime,
        hasActiveAiCallContext = {
            val state = viewModel.internalUiState.value
            state.showAiCallPage ||
                state.currentCallId?.isNotBlank() == true ||
                viewModel.pendingAiCallLaunch
        },
        restartCallSessionPolling = { viewModel.startCallSessionPolling() },
        loadConversations = { viewModel.loadConversations() },
        log = viewModel::internalLog
    )

    val voiceEntryActionHandler = VoiceEntryActionHandler(viewModel)
    val agentDocumentActionHandler by lazy { AssistantAgentDocumentActionHandler(viewModel) }
    val userDecisionActionHandler by lazy { AssistantUserDecisionActionHandler(viewModel) }
    val channelSessionClient by lazy { AssistantChannelSessionClient(viewModel) }
    val outboundCallAudioGate by lazy { AssistantOutboundCallAudioGate(viewModel) }
    val runtimeLifecycleHandler by lazy { AssistantViewModelRuntimeLifecycleHandler(viewModel) }
    val taskConversationLifecycleHandler by lazy {
        val lifecycleStateAccess = AssistantTaskConversationLifecycleStateAccess(
            taskRestoreStateHolder = taskRestoreStateHolder,
            exitResetStateReader = TaskConversationExitResetStateReader(viewModel.internalUiState),
            backgroundPauseStateHolder = TaskConversationBackgroundPauseStateHolder(viewModel.internalUiState),
            listLoadStateHolder = TaskConversationListLoadStateHolder(
                conversationList = viewModel.conversationList,
                conversationLoading = viewModel.conversationLoading,
                conversationError = viewModel.conversationError
            )
        )
        AssistantTaskConversationLifecycleHandler(
            deps = AssistantTaskConversationLifecycleDeps(
                conversationListLoadUseCase = TaskConversationListLoadUseCase(viewModel.repository),
                conversationInterruptUseCase = TaskConversationInterruptUseCase(viewModel.repository),
                scope = viewModel.viewModelScope,
                stateAccess = lifecycleStateAccess,
                accountIdProvider = { AccountIdentityProvider.accountId }
            ),
            callbacks = AssistantTaskConversationLifecycleCallbacks(
                stopVoiceInteraction = viewModel::stopVoiceInteraction,
                resetToIdleHome = viewModel::resetToIdleHome,
                refreshHistory = viewModel::refreshHistory,
                agentSessionId = { viewModel.agentSessionId },
                updateCurrentConversationCardBeforeExit =
                    conversationRestoreHandler::updateCurrentConversationCardBeforeExit,
                rememberPendingExecutionErrorExit = viewModel::rememberPendingExecutionErrorExit,
                pendingExecutionErrorExitSessions = viewModel::pendingExecutionErrorExitSessions,
                pendingExecutionErrorRecoveredSessions = viewModel::pendingExecutionErrorRecoveredSessions,
                syncPendingExecutionErrorExitSessions = viewModel::syncPendingExecutionErrorExitSessions,
                syncPendingExecutionErrorRecoveredSessions = viewModel::syncPendingExecutionErrorRecoveredSessions
            )
        )
    }

    val taskCallHistoryController by lazy {
        TaskCallHistoryController(
            TaskCallHistoryControllerDeps(
                taskRepository = viewModel.taskRepository,
                stateHolder = TaskCallHistoryUiStateHolder(viewModel.internalUiState),
                scope = viewModel.viewModelScope,
                userIdProvider = { DefaultUserId },
                timelineItemsProvider = { viewModel.internalUiState.value.timelineItems },
            )
        )
    }

    val agentStreamHandler by lazy {
        AgentStreamHandler(viewModel, viewModel.repository, timelineRepository) { AccountIdentityProvider.accountId }
    }
    val callActionHandler by lazy { CallActionHandler(viewModel, viewModel.repository) }
    val sessionMapper by lazy {
        val detailPromptUseCase = AssistantSessionDetailPromptUseCase(viewModel.repository)
        SessionMapper(
            SessionMapperDeps(
                uiState = viewModel.internalUiState,
                handlers = SessionMapperHandlers(
                    clarificationStepHandler = AssistantSessionClarificationStepHandler(viewModel),
                    idleResetHandler = AssistantSessionIdleResetHandler(viewModel),
                    detailSupplementHandler = AssistantSessionDetailSupplementHandler(
                        viewModel,
                        detailPromptUseCase
                    ),
                    voicePostApplyHandler = AssistantSessionVoicePostApplyHandler(viewModel)
                ),
                taskState = SessionMapperTaskStateAccess(
                    setTextTaskId = { viewModel.textTaskId = it },
                    setVoiceTaskId = { viewModel.voiceTaskId = it },
                    pendingAiCallLaunch = { viewModel.pendingAiCallLaunch },
                    setPendingAiCallLaunch = { viewModel.pendingAiCallLaunch = it },
                    setPendingFreshTask = { viewModel.pendingFreshTask = it },
                    activeInteractionChannel = { viewModel.activeInteractionChannel },
                    setActiveInteractionChannel = { viewModel.activeInteractionChannel = it }
                ),
                conversationState = SessionMapperConversationStateAccess(
                    pendingSelectionContinuation = { viewModel.pendingSelectionContinuation },
                    setPendingSelectionContinuation = { viewModel.pendingSelectionContinuation = it },
                    clearActiveDialogContext = { viewModel.activeDialogContext = null },
                    setPrimarySummaryAction = { viewModel.primarySummaryAction = it },
                    latestCallPageSeed = { viewModel.latestCallPageSeed },
                    setLatestCallPageSeed = { viewModel.latestCallPageSeed = it },
                    lastCommittedUserTranscript = { viewModel.lastCommittedUserTranscript }
                ),
                detailState = SessionMapperDetailSupplementStateAccess(
                    contactTaskId = { viewModel.detailSupplementContactTaskId },
                    contactValue = { viewModel.detailSupplementContactValue },
                    detailTaskId = { viewModel.detailSupplementInfoTaskId },
                    detailValue = { viewModel.detailSupplementInfoValue },
                    completedTaskId = { viewModel.detailSupplementCompletedTaskId }
                ),
                selectionState = SessionMapperSelectionSuppressionAccess(
                    consumedTaskId = { viewModel.consumedSelectionSheetTaskId },
                    consumedSignature = { viewModel.consumedSelectionSheetSignature },
                    setConsumedTaskId = { viewModel.consumedSelectionSheetTaskId = it },
                    setConsumedSignature = { viewModel.consumedSelectionSheetSignature = it }
                ),
                actions = SessionMapperActions(
                    refreshHistory = viewModel::refreshHistory,
                    stopVoiceInteraction = viewModel::stopVoiceInteraction,
                    log = viewModel::internalLog
                ),
                statusText = SessionMapperStatusText(
                    currentLanguage = viewModel::currentVoiceLanguage,
                    taskReadyStatus = { viewModel.localizedTaskReadyStatus() },
                    contactLabel = { viewModel.localizedContactLabel() },
                    detailLabel = { viewModel.localizedDetailLabel() }
                )
            )
        )
    }
    val voiceDuplexCoordinator by lazy { VoiceDuplexCoordinator(viewModel) }
    val voiceRuntimeHandler by lazy { VoiceRuntimeHandler(viewModel) }
    val localPromptActionHandler by lazy {
        LocalPromptActionHandler(
            deps = LocalPromptDeps(
                uiState = viewModel.internalUiState,
                voiceDuplexCoordinator = voiceDuplexCoordinator
            ),
            callbacks = LocalPromptCallbacks(
                isOutboundCallAudioSuppressed = viewModel::isOutboundCallAudioSuppressed,
                languageCode = { viewModel.voiceLanguageCode },
                setLocalTtsPlaying = { viewModel.localTtsPlaying = it },
                commitAssistantTranscript = {
                    viewModel.lastCommittedAssistantTranscript = it
                    viewModel.appendClarificationStep(VoiceRole.Assistant, it)
                },
                getLastCommittedAssistantTranscript = { viewModel.lastCommittedAssistantTranscript },
                resumeListeningAfterTts = viewModel::resumeListeningAfterTts,
                localizedListeningStatus = { viewModel.localizedListeningStatus() },
                localizedReconnectingVoiceStatus = { viewModel.localizedReconnectingVoiceStatus() },
                getPendingAutoListenAfterSelectionPrompt = {
                    viewModel.pendingAutoListenAfterSelectionPrompt
                },
                setPendingAutoListenAfterSelectionPrompt = {
                    viewModel.pendingAutoListenAfterSelectionPrompt = it
                },
                getActiveInteractionChannel = { viewModel.activeInteractionChannel },
                startVoiceInteraction = viewModel::startVoiceInteraction,
                setPendingDialogTargetScene = { viewModel.pendingDialogTargetScene = it },
                getActiveDialogRunId = { viewModel.activeDialogRunId },
                startApiListening = viewModel::startApiListening,
                log = viewModel::internalLog
            )
        )
    }
}
