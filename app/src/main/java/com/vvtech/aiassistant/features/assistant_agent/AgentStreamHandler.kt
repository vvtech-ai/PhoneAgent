package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineRepository
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Phase 2 拆分：Agent 流式链路 + Agent UI 反馈通道（option 选择 / 表单提交 / 拨打确认 / 修改）。
 * 所有副作用通过 [AssistantViewModel] 暴露的 internal 状态写入；逻辑零修改。
 */
internal class AgentStreamHandler(
    private val viewModel: AssistantViewModel,
    private val repository: AssistantRepository,
    timelineRepository: ConversationTimelineRepository,
    accountIdProvider: () -> String,
) {

    private val timelineCommittedHandler = AgentStreamTimelineCommittedHandler(
        repository = timelineRepository,
        accountIdProvider = accountIdProvider,
        updateState = { reducer -> viewModel.internalUiState.update(reducer) },
        acceptTimelineProjection = viewModel.taskCallHistoryController::acceptTimelineProjection,
    )
    private val isVoiceMode: () -> Boolean = {
        viewModel.activeInteractionChannel == InteractionChannel.VOICE
    }
    private val batchCallRuntimeHandler: AgentStreamBatchCallRuntimeHandler = AgentStreamBatchCallRuntimeHandler(
        callbacks = AgentStreamBatchCallRuntimeCallbacks(
            beginOutboundCallAudioSuppression = viewModel::beginOutboundCallAudioSuppression,
            endOutboundCallAudioSuppression = viewModel::endOutboundCallAudioSuppression,
            cancelTextProcessingStatusProgress = viewModel::cancelTextProcessingStatusProgress,
            updateUiState = { reducer -> viewModel.internalUiState.update(reducer) },
            mutateStep = ::mutateStep
        )
    )
    private val streamEventSessionGate = AgentStreamEventSessionGate(
        AgentStreamEventSessionGateCallbacks(
            currentSessionId = { viewModel.agentSessionId },
            currentState = { viewModel.internalUiState.value },
            hasActiveBatchCallStream = batchCallRuntimeHandler::isActive,
            clearActiveBatchCallState = batchCallRuntimeHandler::clear,
        )
    )
    private val callResultRuntimeHandler: AgentStreamCallResultRuntimeHandler = AgentStreamCallResultRuntimeHandler(
        isVoiceMode = isVoiceMode
    )
    private val terminalSideEffectHandler: AgentStreamTerminalSideEffectHandler = AgentStreamTerminalSideEffectHandler(
        clearPrimarySummaryAction = { viewModel.primarySummaryAction = null },
        clearPendingAiCallLaunch = { viewModel.pendingAiCallLaunch = false },
        stopCallSessionPolling = viewModel::stopCallSessionPolling,
        stopApiListening = viewModel::stopApiListening,
        applyUiState = { nextState -> viewModel.internalUiState.update { nextState } },
        conversationListProvider = { viewModel.conversationList.value },
        setConversationList = { nextList -> viewModel.conversationList.value = nextList },
        loadConversations = viewModel::loadConversations
    )
    private val ttsBridgeHandler: AgentStreamTtsBridgeHandler = AgentStreamTtsBridgeHandler(
        runtime = AgentStreamTtsBridgeRuntime(
            isVoiceMode = isVoiceMode,
            isCallDialogAudioSuppressed = viewModel::isOutboundCallAudioSuppressed,
            outboundCallAudioGateSnapshot = viewModel::outboundCallAudioGateSnapshot,
            previewText = ::previewText
        ),
        callbacks = AgentStreamTtsBridgeCallbacks(
            feedAgentTextDelta = viewModel.voiceDuplexCoordinator::feedAgentTextDelta,
            feedAgentSignalText = viewModel.voiceDuplexCoordinator::feedAgentSignalText,
            flushAgentTts = viewModel.voiceDuplexCoordinator::flushAgentTts,
            suspendDialogAudioForCall = viewModel.voiceDuplexCoordinator::suspendDialogAudioForCall,
            logOutboundCallAudioGate = viewModel::logOutboundCallAudioGate
        )
    )
    private val committedReplyNarrationCoordinator = AgentStreamCommittedReplyNarrationCoordinator(
        isVoiceMode = isVoiceMode,
        taskIdProvider = { viewModel.internalUiState.value.taskId },
        maybeTtsSignal = ttsBridgeHandler::onSignal,
    )
    private val timelineProjectionGate = AgentStreamTimelineProjectionGate(
        currentSessionId = { viewModel.agentSessionId },
        applyProjection = { projection ->
            timelineCommittedHandler.applyProjection(projection)
            committedReplyNarrationCoordinator.onProjectionApplied(projection)
        },
        onDecision = AgentStreamTimelineProjectionLogger::log,
    )
    private val failureRecoveryHandler: AgentStreamFailureRecoveryHandler = AgentStreamFailureRecoveryHandler(
        runtime = AgentStreamFailureRecoveryRuntime(
            stateProvider = { viewModel.internalUiState.value },
            isVoiceMode = isVoiceMode,
            currentVoiceLanguage = viewModel::currentVoiceLanguage,
            hasActiveBatchCallStream = batchCallRuntimeHandler::isActive,
            isOutboundCallAudioSuppressed = viewModel::isOutboundCallAudioSuppressed,
            batchSyncPendingStatusText = { BATCH_CALL_SYNC_PENDING_STATUS },
            sessionIdProvider = { viewModel.agentSessionId }
        ),
        callbacks = AgentStreamFailureRecoveryCallbacks(
            cancelTextProcessingStatusProgress = viewModel::cancelTextProcessingStatusProgress,
            mutateStep = ::mutateStep,
            finalizeStep = ::finalizeStreamingStep,
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            clearActiveBatchCallState = batchCallRuntimeHandler::clear,
            stopApiListening = viewModel::stopApiListening,
            syncCurrentTimeline = { syncCurrentTimelineAfterCallOutcome() },
            loadConversations = viewModel::loadConversations,
            applyNetworkTaskErrorState = viewModel::applyNetworkTaskErrorState,
            markTaskErrorRecoveryInProgress = viewModel::markTaskErrorRecoveryInProgress,
            startApiListening = { trigger -> viewModel.startApiListening(trigger) },
            suspendDialogAudioForCall = viewModel.voiceDuplexCoordinator::suspendDialogAudioForCall,
            releaseStreamOwnership = timelineProjectionGate::onStreamTerminal,
            onRecoverableVoiceTurnNetworkFailure =
                viewModel.voiceRecoverableTurnCoordinator::onNetworkFailure,
        )
    )
    private val stepMutationHandler: AgentStreamStepMutationHandler = AgentStreamStepMutationHandler(
        callbacks = AgentStreamStepMutationCallbacks(
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            batchCallFinalStepPatch = batchCallRuntimeHandler::buildFinalStepPatch,
            maybeTtsSignal = ttsBridgeHandler::onSignal,
            applyAgentResponseState = ::applyAgentResponseState,
            releaseStreamOwnership = timelineProjectionGate::onStreamTerminal,
        )
    )
    private val actionGraph = AgentStreamActionRuntimeGraph(
        viewModel = viewModel,
        repository = repository,
        accountIdProvider = accountIdProvider,
        isVoiceMode = isVoiceMode,
        callResultRuntimeHandler = callResultRuntimeHandler,
        failureRecoveryHandler = failureRecoveryHandler,
        stepMutationHandler = stepMutationHandler,
        applyStreamEvent = ::applyStreamEventIfCurrentSession,
        appendStreamingAssistantStep = ::appendStreamingAssistantStep,
        releaseStreamOwnership = timelineProjectionGate::onStreamTerminal,
    )
    private val responseRuntimeGraph = AgentStreamResponseRuntimeGraph(
        viewModel = viewModel,
        isVoiceMode = isVoiceMode,
        ttsBridgeHandler = ttsBridgeHandler,
        failureRecoveryHandler = failureRecoveryHandler,
        callResultRuntimeHandler = callResultRuntimeHandler,
        batchCallRuntimeHandler = batchCallRuntimeHandler,
        terminalSideEffectHandler = terminalSideEffectHandler,
        scheduleAutoAgentCallConfirm = { actionGraph.scheduleAutoAgentCallConfirm() },
        onTaskResultApplied = committedReplyNarrationCoordinator::onTaskResultApplied,
    )
    private val streamEventHandler = AgentStreamEventHandler(
        runtime = AgentStreamEventRuntimeCallbacks(
            isVoiceMode = isVoiceMode,
            currentVoiceLanguage = viewModel::currentVoiceLanguage,
            cancelTextProcessingStatusProgress = viewModel::cancelTextProcessingStatusProgress,
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            stopApiListening = { viewModel.stopApiListening() },
            loadConversations = { viewModel.loadConversations() },
            logTts = { message -> AppFileLogger.d("TTS_DIAG", message) },
            logStream = { message -> AppFileLogger.d("AgentStream", message) }
        ),
        steps = AgentStreamEventStepCallbacks(
            mutateStep = ::mutateStep,
            finalizeStep = ::finalizeStreamingStep,
            responseStepInput = stepMutationHandler::responseStepInput
        ),
        voice = AgentStreamEventVoiceCallbacks(
            maybeTtsDelta = ttsBridgeHandler::onDelta,
            maybeTtsSignal = ttsBridgeHandler::onSignal,
            failVoiceStream = { failure -> throw AgentStreamFailure(failure) }
        ),
        batch = AgentStreamEventBatchCallbacks(
            markActiveStream = batchCallRuntimeHandler::markStream,
            holdUiForActiveStream = batchCallRuntimeHandler::holdUi,
            applyProgress = batchCallRuntimeHandler::applyProgress,
            isActiveStep = batchCallRuntimeHandler::isActiveStep,
            clearActiveState = batchCallRuntimeHandler::clear,
            syncPendingStatusText = { BATCH_CALL_SYNC_PENDING_STATUS }
        ),
        response = AgentStreamEventResponseCallbacks(
            applyResponseState = ::applyAgentResponseState
        )
    )
    private val turnRunner = AgentStreamTurnRunner(
        runtime = AgentStreamTurnRuntime(
            scope = viewModel.viewModelScope,
            streamUseCase = AgentStreamTurnUseCase(repository),
            stateProvider = { viewModel.internalUiState.value },
            userContextProvider = { reason, message -> viewModel.currentFreshAgentUserContext(reason, message) },
            isVoiceMode = isVoiceMode,
            currentVoiceLanguage = viewModel::currentVoiceLanguage,
            userIdProvider = accountIdProvider
        ),
        callbacks = AgentStreamTurnCallbacks(
            hasActiveBatchCallStream = batchCallRuntimeHandler::isActive,
            holdUiForActiveBatchCall = batchCallRuntimeHandler::holdUi,
            appendStreamingAssistantStep = ::appendStreamingAssistantStep,
            resetStreamingStepForRetry = failureRecoveryHandler::resetStreamingStepForRetry,
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            logAgentContext = callResultRuntimeHandler::logAgentContext,
            applyStreamEvent = ::applyStreamEventIfCurrentSession,
            finalizeStreamingStep = ::finalizeAndReleaseStreamingStep,
            syncConversationSnapshotForVoiceRecovery = viewModel::syncConversationSnapshotForVoiceRecovery,
            handleAgentStreamFailure = failureRecoveryHandler::handleStreamFailure,
            logTts = { message -> AppFileLogger.d("TTS_DIAG", message) },
            logStream = { message -> AppFileLogger.i("AgentStream", message) },
            closeCancelledStreamingStep = ::closeCancelledStreamingStep,
            onCommandStarted = { sessionId, identity, message ->
                if (isVoiceMode()) {
                    viewModel.voiceRecoverableTurnCoordinator.onCommandStarted(
                        sessionId,
                        identity,
                        message,
                    )
                }
            },
            onCommandCompleted = { commandId ->
                if (isVoiceMode()) {
                    viewModel.voiceRecoverableTurnCoordinator.onCommandCompleted(commandId)
                }
            },
        )
    )
    fun ensureAgentSession(): String {
        val sessionId = viewModel.agentSessionId
            ?: UUID.randomUUID().toString().also { viewModel.agentSessionId = it }
        AgentInitialSkillLaunchStore.bindToSession(sessionId)
        return sessionId
    }

    fun startStreamingAgentTurn(
        sessionId: String,
        message: String,
        pendingToolCallId: String?,
        selectedContact: SelectedContactTaskContext? = null,
        supersedesCommandId: String? = null,
    ) {
        committedReplyNarrationCoordinator.onTurnStarted(sessionId)
        turnRunner.start(
            sessionId,
            message,
            pendingToolCallId,
            selectedContact,
            supersedesCommandId,
        )
    }

    fun interruptCurrentStream() {
        actionGraph.cancelAutoConfirm()
        if (batchCallRuntimeHandler.isActive()) {
            batchCallRuntimeHandler.holdUi()
            AppFileLogger.i("AgentStream", "keep_batch_call_stream_on_interrupt batchId=${batchCallRuntimeHandler.currentBatchId()}")
            return
        }
        turnRunner.cancelCurrentStream()
    }

    fun appendStreamingAssistantStep(): Int {
        val stepIndex = stepMutationHandler.appendAssistantStep()
        timelineProjectionGate.onStreamStarted(stepIndex)
        return stepIndex
    }

    fun mutateStep(index: Int, mutator: (ClarificationStep) -> ClarificationStep) =
        stepMutationHandler.mutateStep(index, mutator)

    fun finalizeStreamingStep(index: Int) =
        stepMutationHandler.finalizeStep(index)

    private fun finalizeAndReleaseStreamingStep(index: Int) {
        stepMutationHandler.finalizeStep(index)
        timelineProjectionGate.onStreamTerminal(index)
    }

    fun applyStreamEvent(stepIndex: Int, ev: AgentStreamEvent) {
        if (ev is AgentStreamEvent.TimelineCommitted) {
            committedReplyNarrationCoordinator.onTimelineCommitted(ev.event)
            viewModel.viewModelScope.launch {
                try {
                    timelineProjectionGate.onProjectionReady(
                        projection = timelineCommittedHandler.merge(ev),
                    )
                } catch (cancellation: CancellationException) {
                    throw cancellation
                } catch (throwable: Throwable) {
                    AppFileLogger.w(
                        "AgentStream",
                        "TIMELINE_COMMITTED_MERGE_FAILED " +
                            "sessionId=${ev.event.sessionId} " +
                            "sequence=${ev.event.sequence} " +
                            "exceptionType=${throwable.javaClass.simpleName}",
                        throwable,
                    )
                }
            }
            return
        }
        streamEventHandler.apply(stepIndex, ev)
        if (ev.isTaskResultTerminal()) {
            finalizeOrphanedStreamingSteps(stepIndex)
        }
        if (ev.terminatesStreamingStep()) {
            timelineProjectionGate.onStreamTerminal(stepIndex)
        }
    }

    private fun applyStreamEventIfCurrentSession(
        sessionId: String,
        stepIndex: Int,
        event: AgentStreamEvent,
    ) {
        if (streamEventSessionGate.shouldApply(sessionId, event)) {
            applyStreamEvent(stepIndex, event)
        } else if (event.terminatesStreamingStep()) {
            timelineProjectionGate.onStreamTerminal(stepIndex)
        }
    }

    private fun closeCancelledStreamingStep(
        stepIndex: Int,
        sessionId: String,
        reason: String,
    ) {
        stepMutationHandler.finalizeStep(stepIndex)
        timelineProjectionGate.onStreamTerminal(stepIndex)
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = "AGENT_STREAM_CANCELLED_STEP_FINALIZED",
                sessionId = sessionId,
                taskId = viewModel.internalUiState.value.taskId,
                stateBefore = "streaming",
                stateAfter = "terminal",
                result = "finalized",
                reason = reason,
                attributes = mapOf("stepIndex" to stepIndex.toString()),
            )
        )
    }

    private fun finalizeOrphanedStreamingSteps(terminalStepIndex: Int) {
        val finalized = stepMutationHandler.finalizeOrphanedStreamingSteps()
            .filterNot { it == terminalStepIndex }
        if (finalized.isEmpty()) return
        finalized.forEach(timelineProjectionGate::onStreamTerminal)
        RuntimeStateLogger.warn(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.AGENT,
                eventType = "AGENT_ORPHANED_STREAMING_STEPS_RECOVERED",
                sessionId = viewModel.agentSessionId,
                taskId = viewModel.internalUiState.value.taskId,
                stateBefore = "orphaned_streaming",
                stateAfter = "terminal",
                result = "recovered",
                reason = "task_result_terminal",
                attributes = mapOf(
                    "count" to finalized.size.toString(),
                    "stepIndices" to finalized.joinToString(","),
                ),
            )
        )
    }

    fun syncDeferredCallOutcome(callId: String) {
        if (!isVoiceMode()) return
        val expectedCallId = callId.trim().takeIf(String::isNotEmpty) ?: return
        syncCurrentTimelineAfterCallOutcome(
            requiredOutcome = { projection ->
                projection.hasReportedCallOutcomeForCallId(expectedCallId)
            },
            attempts = DEFERRED_CALL_OUTCOME_SYNC_ATTEMPTS,
        )
    }

    private fun syncCurrentTimelineAfterCallOutcome(
        expectedCallAttemptId: String? = null,
        requireExpectedCallAttempt: Boolean = false,
        requiredOutcome: ((TimelineSnapshotUiProjection) -> Boolean)? = null,
        attempts: Int = CALL_OUTCOME_SYNC_ATTEMPTS,
    ) {
        val sessionId = viewModel.agentSessionId?.trim().orEmpty()
        if (sessionId.isBlank()) {
            AppFileLogger.w("AgentStream", "CALL_OUTCOME_TIMELINE_SYNC skipped reason=missing_session")
            return
        }
        val expectedAttemptId = expectedCallAttemptId?.trim()?.takeIf(String::isNotEmpty)
        val requiresMatchedOutcome = requireExpectedCallAttempt || requiredOutcome != null
        viewModel.viewModelScope.launch {
            var lastFailure: Throwable? = null
            repeat(attempts) { attempt ->
                if (viewModel.agentSessionId?.trim() != sessionId) return@launch
                val result = runCatching { timelineCommittedHandler.sync(sessionId) }
                lastFailure = result.exceptionOrNull()
                val projection = result.getOrNull()
                if (viewModel.agentSessionId?.trim() != sessionId) return@launch
                val terminalReceiptSynced = projection?.let { currentProjection ->
                    when {
                        requiredOutcome != null -> requiredOutcome(currentProjection)
                        requireExpectedCallAttempt ->
                            expectedAttemptId?.let(currentProjection::hasTerminalCallReceipt) == true
                        else -> currentProjection.hasTerminalCallReceipt
                    }
                } == true
                val projectionDecision =
                    if (projection != null && (!requiresMatchedOutcome || terminalReceiptSynced)) {
                        timelineProjectionGate.onProjectionReady(projection)
                    } else {
                        null
                    }
                if (terminalReceiptSynced) {
                    AppFileLogger.i(
                        "AgentStream",
                        "CALL_OUTCOME_TIMELINE_SYNC sessionId=$sessionId result=terminal " +
                            "attempt=${attempt + 1} projection=${projectionDecision?.result ?: "not_submitted"}"
                    )
                    return@launch
                }
                if (attempt < attempts - 1) {
                    delay(CALL_OUTCOME_SYNC_RETRY_DELAY_MS * (attempt + 1))
                }
            }
            AppFileLogger.w(
                "AgentStream",
                "CALL_OUTCOME_TIMELINE_SYNC sessionId=$sessionId result=pending " +
                    "reason=${lastFailure?.javaClass?.simpleName ?: "terminal_not_committed"}"
            )
        }
    }

    fun handleAgentResponse(response: AgentChatResponse) =
        stepMutationHandler.appendResponseStep(response)

    // 状态切换部分，不 append 助手气泡 step（流式链路已经有了 streaming step）
    fun applyAgentResponseState(response: AgentChatResponse) {
        responseRuntimeGraph.apply(response)
        if (response.type == "CALL_RESULT") {
            syncCurrentTimelineAfterCallOutcome(
                expectedCallAttemptId = response.callResult?.metadata?.get("callAttemptId"),
                requireExpectedCallAttempt = true,
            )
        }
    }

    fun onAgentOptionSelect(optionId: String) {
        actionGraph.onAgentOptionSelect(optionId)
    }

    fun onAgentAnswerSubmit(answers: Map<String, Any>) {
        actionGraph.onAgentAnswerSubmit(answers)
    }

    fun onAgentPermissionResult(
        permissionKey: String,
        androidPermission: String?,
        status: String,
        granted: Boolean,
        message: String?
    ) {
        actionGraph.onAgentPermissionResult(
            permissionKey = permissionKey,
            androidPermission = androidPermission,
            status = status,
            granted = granted,
            message = message
        )
    }

    fun onAgentDocumentSubmit(result: DocumentParseResult) {
        actionGraph.onAgentDocumentSubmit(result)
    }

    fun onAgentLookupContactResult(payload: Map<String, Any?>) {
        actionGraph.onAgentLookupContactResult(payload)
    }

    fun onAgentLookupDeviceContactsResolved(
        results: List<Map<String, Any?>>,
        echoText: String? = null,
        pendingSelection: DeviceContactSelectionUiState? = null
    ) {
        actionGraph.onAgentLookupDeviceContactsResolved(results, echoText, pendingSelection)
    }

    fun onAgentDeviceContactSelectionConfirm(
        selectedByName: Map<String, DeviceContactSelectionCandidateUi>,
        echoSelection: Boolean = true
    ) {
        actionGraph.onAgentDeviceContactSelectionConfirm(selectedByName, echoSelection)
    }

    fun tryHandleAgentDeviceContactVoiceSelection(rawText: String): Boolean {
        return actionGraph.tryHandleAgentDeviceContactVoiceSelection(rawText)
    }

    fun onAgentDeviceContactSelectionCancel() {
        actionGraph.onAgentDeviceContactSelectionCancel()
    }

    fun onAgentCallConfirm(auto: Boolean = false) {
        actionGraph.onAgentCallConfirm(auto)
    }

    fun onAgentCallEdit() {
        actionGraph.onAgentCallEdit()
    }

}


private const val BATCH_CALL_SYNC_PENDING_STATUS = "多路外呼结果同步中，请稍后刷新"
private const val CALL_OUTCOME_SYNC_ATTEMPTS = 4
private const val DEFERRED_CALL_OUTCOME_SYNC_ATTEMPTS = 8
private const val CALL_OUTCOME_SYNC_RETRY_DELAY_MS = 500L

private fun AgentStreamEvent.isTaskResultTerminal(): Boolean {
    val response = when (this) {
        is AgentStreamEvent.Signal -> payload
        is AgentStreamEvent.Final -> payload
        else -> return false
    }

    return response.type == "CALL_RESULT" || response.type == "BATCH_CALL_RESULT"
}
