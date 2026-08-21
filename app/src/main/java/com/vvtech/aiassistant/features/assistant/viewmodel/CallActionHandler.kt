package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.ResultSummaryPayload
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.TakeoverAudioSocketClient
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionCommandUseCase
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionPollingController
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionPollingControllerDeps
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionStatusApplyControllerFactory
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionStatusApplyLogging
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionStatusApplyRuntimeActions
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionStatusApplyStateAccess
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionTakeoverAudioController
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionTakeoverAudioControllerDeps
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallMonitorController
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallMonitorControllerDeps
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionTerminalStatusRuntimeActions
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionUserCommandController
import com.vvtech.aiassistant.features.assistant_tasks.TaskCallSessionUserCommandControllerDeps
import com.vvtech.aiassistant.features.assistant_tasks.TaskReceiptStateHolder
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_tasks.mergeTaskCallSessionTranscript
import kotlinx.coroutines.flow.update

/**
 * Phase 2 拆分：通话生命周期 + 人工接管 + 通话会话轮询。
 * 状态访问通过 [AssistantViewModel] 暴露的 internal 入口；逻辑零修改。
 */
internal class CallActionHandler(
    private val viewModel: AssistantViewModel,
    private val repository: AssistantRepository
) {
    private val taskReceiptStateHolder = TaskReceiptStateHolder(viewModel.internalUiState)
    private val callSessionCommandUseCase = TaskCallSessionCommandUseCase(repository)
    private val callSessionPollingController = TaskCallSessionPollingController(
        TaskCallSessionPollingControllerDeps(
            scope = viewModel.viewModelScope,
            userIdProvider = { DefaultUserId },
            commandUseCase = callSessionCommandUseCase,
            stateProvider = { viewModel.internalUiState.value },
            pendingAiCallLaunchProvider = { viewModel.pendingAiCallLaunch },
            getPollingJob = { viewModel.callSessionPollingJob },
            setPollingJob = { viewModel.callSessionPollingJob = it },
            logDiag = ::logCallPageDiag,
            applyStatus = { response -> applyCallSessionStatus(response, appendNote = false) },
            onRefreshFailure = { throwable -> viewModel.applyNetworkTaskErrorState(throwable.message) },
            audioGateSnapshot = { viewModel.outboundCallAudioGateSnapshot() }
        )
    )
    private val takeoverAudioController = TaskCallSessionTakeoverAudioController(
        deps = TaskCallSessionTakeoverAudioControllerDeps(
            scope = viewModel.viewModelScope,
            stateProvider = { viewModel.internalUiState.value },
            activeCallIdProvider = { viewModel.activeTakeoverCallId },
            setActiveCallId = { viewModel.activeTakeoverCallId = it },
            earliestStartProvider = { viewModel.takeoverAudioEarliestStartElapsed },
            setEarliestStart = { viewModel.takeoverAudioEarliestStartElapsed = it },
            setProtectUntil = { viewModel.takeoverStateProtectUntilElapsed = it },
            reconnectJobProvider = { viewModel.takeoverReconnectJob },
            setReconnectJob = { viewModel.takeoverReconnectJob = it },
            socketClient = viewModel.takeoverAudioSocketClient,
            appendNote = ::appendCallNote,
            updateState = { reducer -> viewModel.internalUiState.update(reducer) }
        ),
        audioStartDelayMillis = TakeoverAudioStartDelayMillis,
        reconnectDelayMillis = TakeoverReconnectDelayMillis
    )
    private val callMonitorController = TaskCallMonitorController(
        TaskCallMonitorControllerDeps(
            scope = viewModel.viewModelScope,
            repository = repository,
            userIdProvider = { DefaultUserId },
            stateProvider = { viewModel.internalUiState.value },
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            socketClient = viewModel.callMonitorAudioSocketClient
        )
    )
    private val callSessionStatusApplyController = TaskCallSessionStatusApplyControllerFactory.create(
        state = TaskCallSessionStatusApplyStateAccess(
            currentState = { viewModel.internalUiState.value },
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            lastAppliedDialogueDetail = { viewModel.lastAppliedCallDialogueDetail },
            setLastAppliedDialogueDetail = { viewModel.lastAppliedCallDialogueDetail = it },
            lastAppliedStatusAt = { viewModel.lastAppliedCallStatusAt },
            setLastAppliedStatusAt = { viewModel.lastAppliedCallStatusAt = it },
            activeTakeoverCallId = { viewModel.activeTakeoverCallId },
            takeoverStateProtectUntilElapsed = { viewModel.takeoverStateProtectUntilElapsed },
            agentSessionId = { viewModel.agentSessionId },
            pendingAiCallLaunch = { viewModel.pendingAiCallLaunch },
            setPendingAiCallLaunch = { viewModel.pendingAiCallLaunch = it }
        ),
        runtime = TaskCallSessionStatusApplyRuntimeActions(
            mergeTranscript = ::mergeCallTranscript,
            logTranscript = { message, taskId ->
                AppFileLogger.logConversation(
                    direction = "call_transcript",
                    source = "call_session_status",
                    message = message,
                    sessionId = viewModel.agentSessionId,
                    taskId = taskId
                )
            },
            ensureTakeoverAudioSocket = ::ensureTakeoverAudioSocket,
            stopTakeoverAudioSocket = ::stopTakeoverAudioSocket
        ),
        terminalRuntime = TaskCallSessionTerminalStatusRuntimeActions(
            stopCallSessionPolling = ::stopCallSessionPolling,
            stopTakeoverAudioSocket = ::stopTakeoverAudioSocket,
            clearTakeoverProtectWindow = takeoverAudioController::clearProtectWindow,
            applyCallOutcomePendingDisplay = taskReceiptStateHolder::applyCallOutcomePendingDisplay,
            syncDeferredAgentOutcome = { callId ->
                viewModel.agentStreamHandler.syncDeferredCallOutcome(callId)
            },
        ),
        logging = TaskCallSessionStatusApplyLogging(
            internalLog = viewModel::internalLog,
            logStatusResponse = ::logCallStatusResponse
        )
    )
    private val userCommandController = TaskCallSessionUserCommandController(
        TaskCallSessionUserCommandControllerDeps(
            scope = viewModel.viewModelScope,
            userIdProvider = { DefaultUserId },
            stateProvider = { viewModel.internalUiState.value },
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            commandUseCase = callSessionCommandUseCase,
            stopAssistantSpeech = viewModel.assistantSpeechPlayer::stop,
            stopVoiceInteraction = { viewModel.stopVoiceInteraction() },
            prepareHumanTakeoverRequest = takeoverAudioController::prepareHumanTakeoverRequest,
            clearTakeoverProtectWindow = takeoverAudioController::clearProtectWindow,
            stopTakeoverAudioSocket = ::stopTakeoverAudioSocket,
            stopCallSessionPolling = ::stopCallSessionPolling,
            applyCallSessionStatus = ::applyCallSessionStatus,
            dismissAiCallPage = ::dismissAiCallPage,
            appendCallNote = ::appendCallNote
        )
    )

    fun dismissAiCallPage() {
        logCallPageDiag("dismissAiCallPage_before")
        stopCallSessionPolling()
        callMonitorController.stop()
        stopTakeoverAudioSocket()
        viewModel.lastAppliedCallStatusAt = null
        viewModel.lastAppliedCallDialogueDetail = null
        takeoverAudioController.clearProtectWindow()
        viewModel.internalUiState.update {
            it.copy(
                showAiCallPage = false,
                callUiMode = CallUiMode.Ai,
                currentCallId = null,
                handoffInFlight = false,
                callMonitorState = CallMonitorPlaybackState.Off,
                callMonitorAudioRouteState = CallMonitorAudioRouteState(),
                humanMicrophoneMuted = false
            )
        }
        logCallPageDiag("dismissAiCallPage_after")
    }

    fun requestHumanTakeover() {
        callMonitorController.stop()
        userCommandController.requestHumanTakeover()
    }

    fun toggleCallMonitor() {
        if (viewModel.internalUiState.value.callUiMode == CallUiMode.Ai) {
            callMonitorController.toggle()
        }
    }

    fun selectCallMonitorAudioRoute(route: CallMonitorAudioRoute) {
        if (viewModel.internalUiState.value.callUiMode == CallUiMode.Ai) {
            callMonitorController.selectAudioRoute(route)
        }
    }

    fun setHumanTakeoverSoundEnabled(enabled: Boolean) {
        if (viewModel.internalUiState.value.callUiMode != CallUiMode.Human) {
            toggleCallMonitor()
            return
        }
        takeoverAudioController.setCaptureEnabled(enabled)
        viewModel.internalUiState.update { it.copy(humanMicrophoneMuted = !enabled) }
        appendCallNote(
            if (enabled) {
                currentAppText("人工接管麦克风已恢复", "Takeover microphone unmuted")
            } else {
                currentAppText("人工接管麦克风已静音", "Takeover microphone muted")
            }
        )
    }

    fun setHumanTakeoverSpeakerEnabled(enabled: Boolean) {
        if (viewModel.internalUiState.value.callUiMode != CallUiMode.Human) {
            return
        }
        takeoverAudioController.setSpeakerphoneEnabled(enabled)
        appendCallNote(
            if (enabled) {
                currentAppText("已开启免提", "Speakerphone on")
            } else {
                currentAppText("已关闭免提", "Speakerphone off")
            }
        )
    }

    fun releaseToAi() {
        userCommandController.releaseToAi()
    }

    fun hangUpCall(onFinished: (() -> Unit)? = null) {
        callMonitorController.stop()
        userCommandController.hangUpCall(onFinished = onFinished)
    }

    fun startCallSessionPolling() {
        callSessionPollingController.start()
    }

    fun stopCallSessionPolling() {
        callSessionPollingController.stop()
    }

    fun refreshCallSessionStatus() {
        callSessionPollingController.refresh()
    }

    fun ensureTakeoverAudioSocket(taskId: String?, callId: String?) {
        takeoverAudioController.ensure(taskId, callId)
    }

    fun stopTakeoverAudioSocket() {
        takeoverAudioController.stop()
    }

    fun handleTakeoverAudioEvent(event: TakeoverAudioSocketClient.Event) {
        takeoverAudioController.handleEvent(event)
    }

    fun scheduleTakeoverReconnect(delayMillis: Long = 450L) {
        takeoverAudioController.scheduleReconnect(delayMillis)
    }

    fun applyCallSessionStatus(
        response: CallSessionStatusResponse,
        appendNote: Boolean
    ) {
        callSessionStatusApplyController.apply(response, appendNote)
        if (response.callState.trim().uppercase() in setOf("ENDED", "FAILED", "NOT_FOUND")) {
            callMonitorController.stop()
        }
    }

    fun mergeCallTranscript(
        currentTranscript: List<TranscriptLine>,
        dialogueDetail: String?
    ): List<TranscriptLine> {
        val normalized = dialogueDetail?.trim().orEmpty()
        val result = mergeTaskCallSessionTranscript(
            currentTranscript = currentTranscript,
            previousDialogueDetail = viewModel.lastAppliedCallDialogueDetail,
            dialogueDetail = normalized
        )
        viewModel.lastAppliedCallDialogueDetail = result.lastAppliedDialogueDetail
        return result.transcript
    }

    fun shouldKeepPollingCallSession(state: Index9AssistantUiState): Boolean {
        return callSessionPollingController.shouldKeepPolling(state)
    }

    fun appendCallResult(result: ResultSummaryPayload) {
        val statusText = buildResultSummaryStatus(result)
        AppFileLogger.logConversation(
            direction = "call_result",
            source = "call_action_handler",
            message = statusText,
            sessionId = viewModel.agentSessionId,
            taskId = viewModel.internalUiState.value.taskId
        )
        taskReceiptStateHolder.applyCallResultStatus(statusText)
    }

    fun appendCallNote(note: String) {
        AppFileLogger.logConversation(
            direction = "call_note",
            source = "call_action_handler",
            message = note,
            sessionId = viewModel.agentSessionId,
            taskId = viewModel.internalUiState.value.taskId
        )
        taskReceiptStateHolder.appendCallNote(note)
    }

    private fun logCallPageDiag(reason: String) {
        val state = viewModel.internalUiState.value
        AppFileLogger.i(
            "CALL_PAGE_DIAG",
            "reason=$reason showAiCallPage=${state.showAiCallPage} " +
                "pendingAiCallLaunch=${viewModel.pendingAiCallLaunch} " +
                "currentCallId=${state.currentCallId.orEmpty()} taskId=${state.taskId.orEmpty()} " +
                "callUiMode=${state.callUiMode} processingTurn=${state.processingTurn} " +
                "handoffInFlight=${state.handoffInFlight} status=${state.status} " +
                "callStatus=${state.callPageData.status} transcriptLines=${state.callPageData.transcript.size} " +
                viewModel.outboundCallAudioGateSnapshot()
        )
    }

    private fun logCallStatusResponse(
        reason: String,
        response: CallSessionStatusResponse,
        appendNote: Boolean,
        state: Index9AssistantUiState,
        normalizedDialogue: String
    ) {
        AppFileLogger.i(
            "CALL_PAGE_DIAG",
            "reason=$reason appendNote=$appendNote responseTaskId=${response.taskId} " +
                "responseCallId=${response.callId} callState=${response.callState} " +
                "handoff=${response.handoffMode} resultCode=${response.resultCode} " +
                "updatedAt=${response.updatedAt} statusMessage=${response.statusMessage} " +
                "dialogueLen=${normalizedDialogue.length} dialogueHash=${normalizedDialogue.hashCode()} " +
                "stateShowAiCallPage=${state.showAiCallPage} stateCurrentCallId=${state.currentCallId.orEmpty()} " +
                "stateTaskId=${state.taskId.orEmpty()} stateProcessingTurn=${state.processingTurn} " +
                "statePendingAiCallLaunch=${viewModel.pendingAiCallLaunch} " +
                viewModel.outboundCallAudioGateSnapshot()
        )
    }
}
