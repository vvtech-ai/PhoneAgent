package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.CallHandoffRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.ContactResolutionPayload
import com.vvtech.aiassistant.core.model.DetailSupplementPromptResponse
import com.vvtech.aiassistant.core.model.ResultSummaryPayload
import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.core.model.VoiceDialogContextResponse
import com.vvtech.aiassistant.data.repository.AssistantContainer
import com.vvtech.aiassistant.repository.AppContainer
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.model.ConversationDetail
import com.vvtech.aiassistant.model.DeviceContactPayload
import com.vvtech.aiassistant.model.UserContextPayload
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.features.assistant_agent.AgentStreamHandler
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrAttachmentHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.AgentTtsBridge
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUserContextHolder
import com.vvtech.aiassistant.features.assistant.viewmodel.CallActionHandler
import com.vvtech.aiassistant.features.assistant_session.ConversationRestoreHandler
import com.vvtech.aiassistant.features.assistant_session.ConversationSubmitActionHandler
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionActionableSummary
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionPendingSelectionContinuation
import com.vvtech.aiassistant.features.assistant.viewmodel.DetailSupplementActionHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.AssistantUiStateReducer
import com.vvtech.aiassistant.features.assistant.viewmodel.LocalPromptActionHandler
import com.vvtech.aiassistant.features.assistant_session.SessionMapper
import com.vvtech.aiassistant.features.assistant.viewmodel.AutoResumeListeningDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.MaxAiSpeechResumeDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.MinAiSpeechResumeDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.TakeoverAudioStartDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.TakeoverReconnectDelayMillis
import com.vvtech.aiassistant.features.assistant_tasks.TaskErrorRecoveryHolder
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallHistoryController
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallHistoryEntry
import com.vvtech.aiassistant.features.assistant.viewmodel.VoiceEntryActionHandler
import com.vvtech.aiassistant.features.assistant.viewmodel.appendClarificationStepIfMissing
import com.vvtech.aiassistant.features.assistant.viewmodel.buildCallHistoryMetaDetail
import com.vvtech.aiassistant.features.assistant.viewmodel.buildResultSummaryStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.extractVisibleAssistantDialogueText
import com.vvtech.aiassistant.features.assistant.viewmodel.isBackendStateMachineScene
import com.vvtech.aiassistant.features.assistant.viewmodel.isTerminalTask
import com.vvtech.aiassistant.features.assistant.viewmodel.mapClarificationSteps
import com.vvtech.aiassistant.features.assistant.viewmodel.maxStage
import com.vvtech.aiassistant.features.assistant.viewmodel.normalizePersistedHistoryMeta
import com.vvtech.aiassistant.features.assistant.viewmodel.parseCallDialogueDetail
import com.vvtech.aiassistant.features.assistant.viewmodel.parseCallSessionUpdatedAt
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.resolveLatestBackendAssistantPrompt
import com.vvtech.aiassistant.features.assistant.viewmodel.resolveSelectionSheetFromSession
import com.vvtech.aiassistant.features.assistant.viewmodel.removeTrailingAssistantPrompt
import com.vvtech.aiassistant.features.assistant.viewmodel.sameTranscriptLine
import com.vvtech.aiassistant.features.assistant.viewmodel.sceneLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.summarizeHistoryMeta
import com.vvtech.aiassistant.features.assistant.viewmodel.supportsSelectionDrivenDetailSupplement
import com.vvtech.aiassistant.features.assistant.viewmodel.taskSortKey
import com.vvtech.aiassistant.features.assistant.viewmodel.textProcessingStatusLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.toHistoryRecord
import com.vvtech.aiassistant.features.assistant_actions.AssistantAgentDocumentActionHandler
import com.vvtech.aiassistant.features.assistant_actions.AssistantUserDecisionActionHandler
import com.vvtech.aiassistant.features.assistant_audio.AssistantOutboundCallAudioGate
import com.vvtech.aiassistant.features.assistant_lifecycle.AssistantViewModelHandlerGraph
import com.vvtech.aiassistant.features.assistant_lifecycle.AssistantViewModelRuntimeLifecycleHandler
import com.vvtech.aiassistant.features.assistant_session.AssistantChannelSessionClient
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionSelectionSheetPolicy
import com.vvtech.aiassistant.features.assistant_tasks.AssistantTaskConversationLifecycleHandler
import com.vvtech.aiassistant.features.assistant_status.AssistantLocalizedStatusTextProvider
import com.vvtech.aiassistant.features.assistant_voice.AssistantVoiceLanguageState
import com.vvtech.aiassistant.features.assistant_voice.TaskAsrClient
import com.vvtech.aiassistant.features.assistant_voice.TaskVoiceClientFactory
import com.vvtech.aiassistant.features.assistant_voice.VoiceRecognizedInputDedupTracker
import com.vvtech.aiassistant.features.assistant_voice.VoiceRecoverableTurnCoordinator
import com.vvtech.aiassistant.features.assistant.speech.AudioPlayer
import com.vvtech.aiassistant.features.assistant.speech.AudioRecorder
import com.vvtech.aiassistant.features.assistant.speech.TtsApiClient
import com.vvtech.aiassistant.voice.VoiceRuntimeEvent
import com.vvtech.aiassistant.voice.VoiceTranscriptSpeaker
import java.util.ArrayDeque
import java.util.Locale
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZonedDateTime
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class AssistantViewModel(
    application: Application
) : AndroidViewModel(application) {

    private companion object {
        private const val TAG = "Index9AssistantVM"
    }

    internal val repository = AssistantContainer.repository
    internal val taskRepository = AppContainer.taskRepository
    internal val appContext = application.applicationContext
    private val voiceLanguageState = AssistantVoiceLanguageState(appContext)
    internal val voiceLanguageCode: String
        get() = voiceLanguageState.code
    internal val assistantSpeechPlayer = AssistantSpeechPlayerHolder.get(appContext)
    internal val liveSpeechClient = LiveSpeechTranscriptionSocketClient(appContext)
    internal val takeoverAudioSocketClient = TakeoverAudioSocketClient(appContext)
    internal val callMonitorAudioSocketClient =
        com.vvtech.aiassistant.features.assistant_audio.CallMonitorAudioSocketClient(appContext)
    internal val speechRecognizer = AndroidSpeechRecognizer(appContext)
    internal val audioRecorder = AudioRecorder()
    internal val taskVoiceProvider: String =
        com.vvtech.aiassistant.BuildConfig.TASK_VOICE_PROVIDER.lowercase(Locale.US)
    internal val qwenTaskVoiceEnabled: Boolean = isBackendTaskVoiceProvider(taskVoiceProvider)
    private val taskVoiceClients = TaskVoiceClientFactory.create(appContext)
    internal val taskAsrClient: TaskAsrClient = taskVoiceClients.asrClient
    internal val ttsApiClient: TtsApiClient = taskVoiceClients.ttsClient
    internal val audioPlayer = AudioPlayer(context = appContext)
    internal val ttsBridge by lazy {
        AgentTtsBridge(
            ttsClient = ttsApiClient,
            audioPlayer = audioPlayer,
            scope = viewModelScope,
            languageCodeProvider = { voiceLanguageCode }
        )
    }
    private val _uiState = MutableStateFlow(Index9AssistantUiState())
    val uiState: StateFlow<Index9AssistantUiState> = _uiState.asStateFlow()
    internal val localizedStatusTextProvider =
        AssistantLocalizedStatusTextProvider(::currentVoiceLanguage)

    val conversationList = MutableStateFlow<List<ConversationListItem>>(emptyList())
    val conversationLoading = MutableStateFlow(false)
    val conversationError = MutableStateFlow<String?>(null)
    private val handlerGraph = AssistantViewModelHandlerGraph(this)
    internal val conversationRestoreHandler: ConversationRestoreHandler
        get() = handlerGraph.conversationRestoreHandler
    internal val userContextHolder: AssistantUserContextHolder
        get() = handlerGraph.userContextHolder
    internal val pureVoiceOcrAttachmentHandler: PureVoiceOcrAttachmentHandler
        get() = handlerGraph.pureVoiceOcrAttachmentHandler
    internal val conversationSubmitActionHandler: ConversationSubmitActionHandler
        get() = handlerGraph.conversationSubmitActionHandler
    internal val detailSupplementActionHandler: DetailSupplementActionHandler
        get() = handlerGraph.detailSupplementActionHandler
    internal val taskErrorRecoveryHolder: TaskErrorRecoveryHolder
        get() = handlerGraph.taskErrorRecoveryHolder
    internal val voiceEntryActionHandler: VoiceEntryActionHandler
        get() = handlerGraph.voiceEntryActionHandler
    internal val voiceRecoverableTurnCoordinator: VoiceRecoverableTurnCoordinator
        get() = handlerGraph.voiceRecoverableTurnCoordinator
    internal val agentDocumentActionHandler: AssistantAgentDocumentActionHandler
        get() = handlerGraph.agentDocumentActionHandler
    internal val userDecisionActionHandler: AssistantUserDecisionActionHandler
        get() = handlerGraph.userDecisionActionHandler
    internal val channelSessionClient: AssistantChannelSessionClient
        get() = handlerGraph.channelSessionClient
    internal val outboundCallAudioGate: AssistantOutboundCallAudioGate
        get() = handlerGraph.outboundCallAudioGate
    internal val runtimeLifecycleHandler: AssistantViewModelRuntimeLifecycleHandler
        get() = handlerGraph.runtimeLifecycleHandler
    internal val taskConversationLifecycleHandler: AssistantTaskConversationLifecycleHandler
        get() = handlerGraph.taskConversationLifecycleHandler

    /** Phase 2 拆分：handler 类直接访问的可写状态流入口；保持单一引用源（`_uiState`）。 */
    internal val internalUiState: MutableStateFlow<Index9AssistantUiState> get() = _uiState

    internal var initialized = false
    internal var primarySummaryAction: AssistantActionChip? = null
    internal var latestCallPageSeed: CallPageData = _uiState.value.callPageData
    internal var pendingSpeechTurn: Job? = null
    internal var autoResumeListeningJob: Job? = null
    internal var textProcessingStatusJob: Job? = null
    internal var callSessionPollingJob: Job? = null
    internal val latestUserContext: UserContextPayload?
        get() = userContextHolder.latestTransportUserContext()
    internal var activeTakeoverCallId: String? = null
    internal var speechFallbackStarted = false
    internal var platformSpeechFallbackStarted = false
    internal var backendSpeechFallbackActive = false
    internal var backendSpeechFallbackGeneration = 0L
    internal var pendingFreshTask = false
    internal var lastCommittedUserTranscript: String? = null
    internal var lastCommittedAssistantTranscript: String? = null
    internal val voiceRecognizedInputDedupTracker = VoiceRecognizedInputDedupTracker()
    internal var manualAsrPressGeneration = 0L
    internal var manualAsrButtonPressed = false
    internal var pendingManualAsrFinalTranscript: String? = null
    internal var manualAsrReleaseFallbackJob: Job? = null
    internal var pendingStructuredRecognizedTurn: String? = null
    internal var latestRealtimeAssistantReplyForBackend: String? = null
    internal val queuedRecognizedTurns = ArrayDeque<String>()
    internal var activeDialogContext: VoiceDialogContextResponse? = null
    internal var localTtsPlaying = false
    internal var suppressAutoRestartOnClose = false
    internal var suppressAssistantEventsForCurrentRun = false
    private var silentReconnectCount = 0
    internal var dialogRunCounter = 0
    internal var activeDialogRunId = 0
    internal var pendingDialogTargetScene: String? = null
    internal var pendingCarryoverScene: String? = null
    internal var pendingCarryoverUtterance: String? = null
    internal var pendingSyntheticAssistantPrompt: String? = null
    internal var voiceTaskId: String? = null
    internal var textTaskId: String? = null
    internal var agentSessionId: String? = null
    internal var pendingAiCallLaunch: Boolean = false
    internal var outboundCallAudioSuppressed: Boolean = false

    internal var activeInteractionChannel: InteractionChannel = InteractionChannel.NONE
    internal var pendingDetailActionable: AssistantSessionActionableSummary? = null
    internal var detailSupplementCompletedTaskId: String? = null
    internal var detailSupplementContactTaskId: String? = null
    internal var detailSupplementContactValue: String? = null
    internal var detailSupplementInfoTaskId: String? = null
    internal var detailSupplementInfoValue: String? = null
    internal var lastAppliedCallStatusAt: LocalDateTime? = null
    internal var lastAppliedCallDialogueDetail: String? = null
    internal var takeoverStateProtectUntilElapsed: Long = 0L
    internal var takeoverReconnectJob: Job? = null
    internal var takeoverAudioEarliestStartElapsed: Long = 0L
    internal var consumedSelectionSheetTaskId: String? = null
    internal var consumedSelectionSheetSignature: String? = null
    internal var pendingSelectionContinuation: AssistantSessionPendingSelectionContinuation? = null
    internal var pendingAutoListenAfterSelectionPrompt: Boolean = false

    internal val taskCallHistoryController: TaskCallHistoryController
        get() = handlerGraph.taskCallHistoryController
    internal val agentStreamHandler: AgentStreamHandler
        get() = handlerGraph.agentStreamHandler
    internal val callActionHandler: CallActionHandler
        get() = handlerGraph.callActionHandler
    internal val sessionMapper: SessionMapper
        get() = handlerGraph.sessionMapper
    internal val voiceDuplexCoordinator: VoiceDuplexCoordinator
        get() = handlerGraph.voiceDuplexCoordinator
    internal val voiceRuntimeHandler: VoiceRuntimeHandler
        get() = handlerGraph.voiceRuntimeHandler
    internal val localPromptActionHandler: LocalPromptActionHandler
        get() = handlerGraph.localPromptActionHandler

    fun setVoiceLanguage(languageCode: String) {
        if (voiceLanguageState.set(languageCode)) {
            log("voice language changed to $voiceLanguageCode")
        }
    }

    internal fun currentVoiceLanguage(): VoiceLanguage = voiceLanguageState.language

    // 上述 SessionMapper 域的方法体已搬迁至 assistant_session/SessionMapper.kt。

    override fun onCleared() {
        runtimeLifecycleHandler.onCleared()
        super.onCleared()
    }

    private fun log(message: String) {
        AppFileLogger.i(TAG, message)
    }

    /** Phase 2 拆分：handler 内部需要写日志时通过此入口转发，避免直接暴露 [Log] 调用站点。 */
    internal fun internalLog(message: String) {
        log(message)
    }
}
