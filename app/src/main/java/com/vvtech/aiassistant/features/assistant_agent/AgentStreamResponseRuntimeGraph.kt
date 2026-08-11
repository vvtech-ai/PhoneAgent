package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.appendClarificationStep
import com.vvtech.aiassistant.features.assistant.markTaskErrorRecoveryConfirmed
import com.vvtech.aiassistant.features.assistant.markTaskErrorRecoveryInProgress
import com.vvtech.aiassistant.features.assistant_tasks.callResultStatusText
import com.vvtech.aiassistant.features.assistant_tasks.callResultTaskStatus
import kotlinx.coroutines.flow.update

internal class AgentStreamResponseRuntimeGraph(
    private val viewModel: AssistantViewModel,
    private val isVoiceMode: () -> Boolean,
    ttsBridgeHandler: AgentStreamTtsBridgeHandler,
    failureRecoveryHandler: AgentStreamFailureRecoveryHandler,
    callResultRuntimeHandler: AgentStreamCallResultRuntimeHandler,
    batchCallRuntimeHandler: AgentStreamBatchCallRuntimeHandler,
    terminalSideEffectHandler: AgentStreamTerminalSideEffectHandler,
    scheduleAutoAgentCallConfirm: () -> Unit,
    onTaskResultApplied: (AgentChatResponse) -> Unit,
) {
    private val responseStateHandler: AgentStreamResponseStateHandler = AgentStreamResponseStateHandler(
        runtime = AgentStreamResponseRuntimeCallbacks(
            stateProvider = { viewModel.internalUiState.value },
            updateState = { reducer -> viewModel.internalUiState.update(reducer) },
            latestCallPageSeedProvider = { viewModel.latestCallPageSeed },
            setLatestCallPageSeed = { nextSeed -> viewModel.latestCallPageSeed = nextSeed },
            scheduleAutoAgentCallConfirm = scheduleAutoAgentCallConfirm,
            internalLog = viewModel::internalLog,
            markTaskErrorRecoveryConfirmed = { reason, promoteToRunning ->
                viewModel.markTaskErrorRecoveryConfirmed(
                    reason = reason,
                    promoteToRunning = promoteToRunning
                )
            }
        ),
        voice = AgentStreamResponseVoiceCallbacks(
            isVoiceMode = isVoiceMode,
            currentVoiceLanguage = viewModel::currentVoiceLanguage,
            maybeTtsFlush = ttsBridgeHandler::onFlush,
            maybeTtsSignal = ttsBridgeHandler::onSignal,
            appendAssistantStep = { text -> viewModel.appendClarificationStep(VoiceRole.Assistant, text) },
            markTaskErrorRecoveryInProgress = viewModel::markTaskErrorRecoveryInProgress,
            resumeListeningAfterAgentRecovery = failureRecoveryHandler::resumeListeningAfterAgentRecovery
        ),
        terminal = AgentStreamResponseTerminalCallbacks(
            agentSessionIdProvider = { viewModel.agentSessionId },
            callResultStatusText = ::callResultStatusText,
            callResultTaskStatus = ::callResultTaskStatus,
            logApplyCallResult = callResultRuntimeHandler::logApplyCallResult,
            currentBatchIdProvider = batchCallRuntimeHandler::currentBatchId,
            clearActiveBatchCallState = batchCallRuntimeHandler::clear,
            terminalSideEffectHandler = terminalSideEffectHandler,
            onTaskResultApplied = onTaskResultApplied,
        )
    )

    fun apply(response: AgentChatResponse) {
        responseStateHandler.apply(response)
    }
}
