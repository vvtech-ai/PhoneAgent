package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.AgentCommandIdentity
import com.vvtech.aiassistant.core.model.AgentCommandKind
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.localizedVoiceRecoveryRetryStatus
import com.vvtech.aiassistant.features.assistant.voiceRecoveryDecision
import com.vvtech.aiassistant.features.assistant.viewmodel.runCatchingNonCancellation
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.launch

internal data class AgentStreamTurnRuntime(
    val scope: CoroutineScope,
    val streamUseCase: AgentStreamTurnUseCase,
    val stateProvider: () -> Index9AssistantUiState,
    val userContextProvider: suspend (reason: String, message: String?) -> UserContextPayload,
    val isVoiceMode: () -> Boolean,
    val currentVoiceLanguage: () -> VoiceLanguage,
    val userIdProvider: () -> String,
    val initialLaunchProvider: (String) -> AgentInitialLaunch? = { sessionId ->
        AgentInitialSkillLaunchStore.takeLaunch(sessionId)
    },
)

internal data class AgentStreamTurnCallbacks(
    val hasActiveBatchCallStream: () -> Boolean,
    val holdUiForActiveBatchCall: () -> Unit,
    val appendStreamingAssistantStep: () -> Int,
    val resetStreamingStepForRetry: (stepIndex: Int) -> Unit,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val logAgentContext: (action: String, sessionId: String, context: UserContextPayload) -> Unit,
    val applyStreamEvent: (sessionId: String, stepIndex: Int, event: AgentStreamEvent) -> Unit,
    val finalizeStreamingStep: (stepIndex: Int) -> Unit,
    val syncConversationSnapshotForVoiceRecovery: suspend (sessionId: String, reason: String) -> Boolean,
    val handleAgentStreamFailure: (stepIndex: Int, throwable: Throwable, fallback: String) -> Unit,
    val logTts: (message: String) -> Unit,
    val logStream: (message: String) -> Unit,
    val closeCancelledStreamingStep: (
        stepIndex: Int,
        sessionId: String,
        reason: String
    ) -> Unit = { _, _, _ -> },
    val onCommandStarted: (
        sessionId: String,
        identity: AgentCommandIdentity,
        message: String,
    ) -> Unit = { _, _, _ -> },
    val onCommandCompleted: (commandId: String) -> Unit = {},
)

internal class AgentStreamTurnRunner(
    private val runtime: AgentStreamTurnRuntime,
    private val callbacks: AgentStreamTurnCallbacks
) {
    private data class ActiveStream(
        val token: Any,
        val sessionId: String,
        val stepIndex: Int,
        val job: Job,
    )

    private var activeStream: ActiveStream? = null

    fun start(
        sessionId: String,
        message: String,
        pendingToolCallId: String?,
        selectedContact: SelectedContactTaskContext? = null,
        supersedesCommandId: String? = null,
    ) {
        if (callbacks.hasActiveBatchCallStream()) {
            callbacks.holdUiForActiveBatchCall()
            callbacks.logStream("ignore_new_agent_turn_while_batch_call_active session=$sessionId msg='${message.take(40)}'")
            return
        }
        cancelCurrentStream("superseded_by_new_turn")
        val stepIndex = callbacks.appendStreamingAssistantStep()
        val identity = AgentCommandIdentity.newIntent(sessionId, AgentCommandKind.UserTurn)
        callbacks.onCommandStarted(sessionId, identity, message)
        callbacks.logTts("startStreamingAgentTurn session=$sessionId msg='${message.take(40)}' voice=${runtime.isVoiceMode()}")
        val token = Any()
        val job = runtime.scope.launch(start = CoroutineStart.LAZY) {
            var attempt = 0
            var initialLaunch: AgentInitialLaunch? = null
            var initialLaunchLoaded = false
            while (attempt < 2) {
                val attemptIndex = attempt
                var sawTerminalEvent = false
                val result = runCatchingNonCancellation {
                    if (attemptIndex > 0) {
                        callbacks.resetStreamingStepForRetry(stepIndex)
                        callbacks.updateState {
                            it.copy(
                                error = null,
                                status = localizedVoiceRecoveryRetryStatus(runtime.currentVoiceLanguage())
                            )
                        }
                        delay(650L)
                    }
                    val userContext = runtime.userContextProvider("agent_chat_stream", message)
                    callbacks.logAgentContext("chat_stream", sessionId, userContext)
                    if (!initialLaunchLoaded) {
                        initialLaunch = runtime.initialLaunchProvider(sessionId)
                        initialLaunchLoaded = true
                    }
                    runtime.streamUseCase.stream(
                        AgentStreamTurnUseCaseRequest(
                            sessionId = sessionId,
                            message = message,
                            pendingToolCallId = pendingToolCallId,
                            channel = if (runtime.isVoiceMode()) "voice" else "text",
                            userId = runtime.userIdProvider(),
                            initialSkillId = initialLaunch?.skillId,
                            initialOpening = initialLaunch?.opening,
                            identity = identity,
                            selectedContact = selectedContact,
                            supersedesCommandId = supersedesCommandId,
                        ),
                        userContext
                    ).catch { throw it }.collect { event ->
                        if (event.isTerminalForProcessingTurn()) {
                            sawTerminalEvent = true
                        }
                        callbacks.applyStreamEvent(sessionId, stepIndex, event)
                    }
                }
                val throwable = result.exceptionOrNull()
                if (throwable == null) {
                    if (!sawTerminalEvent && runtime.stateProvider().processingTurn) {
                        callbacks.finalizeStreamingStep(stepIndex)
                        callbacks.syncConversationSnapshotForVoiceRecovery(
                            sessionId,
                            "stream_completed_without_terminal"
                        )
                    }
                    callbacks.onCommandCompleted(identity.commandId)
                    return@launch
                }
                val structuredFailure = (throwable as? AgentStreamFailure)?.failure
                val decision = voiceRecoveryDecision(
                    throwable.message,
                    runtime.currentVoiceLanguage()
                )
                val shouldRetryTransport = structuredFailure == null && decision.retryable
                if (runtime.isVoiceMode() && attemptIndex == 0 && shouldRetryTransport) {
                    attempt += 1
                    continue
                }
                callbacks.handleAgentStreamFailure(stepIndex, throwable, "文字任务提交失败")
                return@launch
            }
        }
        activeStream = ActiveStream(
            token = token,
            sessionId = sessionId,
            stepIndex = stepIndex,
            job = job,
        )
        job.invokeOnCompletion {
            if (activeStream?.token === token) {
                activeStream = null
            }
        }
        job.start()
    }

    fun cancelCurrentStream() {
        cancelCurrentStream("explicit_interrupt")
    }

    private fun cancelCurrentStream(reason: String) {
        val stream = activeStream ?: return
        activeStream = null
        stream.job.cancel()
        callbacks.closeCancelledStreamingStep(
            stream.stepIndex,
            stream.sessionId,
            reason,
        )
    }

    private fun AgentStreamEvent.isTerminalForProcessingTurn(): Boolean =
        this is AgentStreamEvent.Signal ||
            this is AgentStreamEvent.Final ||
            this is AgentStreamEvent.Err
}
