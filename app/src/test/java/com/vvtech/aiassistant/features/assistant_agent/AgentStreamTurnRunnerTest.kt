package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.model.UserContextPayload
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamTurnRunnerTest {
    @Test
    fun agentStreamHandlerDelegatesStreamingTurnRuntimeToRunner() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val runner =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamTurnRunner.kt")
                .readText(Charsets.UTF_8)
        val useCase =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamTurnUseCase.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamTurnRunner("))
        assertTrue(handler.contains("streamUseCase = AgentStreamTurnUseCase(repository)"))
        assertTrue(handler.contains("turnRunner.start("))
        assertTrue(handler.contains("supersedesCommandId,"))
        assertTrue(handler.contains("turnRunner.cancelCurrentStream()"))
        assertTrue(handler.contains("actionGraph.cancelAutoConfirm()"))
        assertTrue(handler.contains("keep_batch_call_stream_on_interrupt"))
        assertFalse(
            handler.contains(
                "AgentStreamTurnRuntime(\n            scope = viewModel.viewModelScope,\n            streamProvider = repository::agentChatStream"
            )
        )

        assertFalse(handler.contains("private var currentStreamJob"))
        assertFalse(handler.contains("runCatchingNonCancellation"))
        assertFalse(handler.contains("repository.agentChatStream("))
        assertFalse(handler.contains("localizedVoiceRecoveryRetryStatus"))
        assertFalse(handler.contains("voiceRecoveryDecision("))
        assertFalse(handler.contains("isTerminalForProcessingTurn"))
        assertFalse(handler.contains("currentStreamJob = viewModel.viewModelScope.launch"))
        assertTrue(handler.contains("projection = timelineCommittedHandler.merge(ev)"))
        assertTrue(handler.contains("timelineProjectionGate.onProjectionReady("))
        assertTrue(handler.contains("catch (cancellation: CancellationException)"))
        assertTrue(handler.contains("TIMELINE_COMMITTED_MERGE_FAILED"))
        assertTrue(handler.contains("timelineProjectionGate.onStreamTerminal(stepIndex)"))

        assertTrue(runner.contains("private var activeStream"))
        assertTrue(runner.contains("runCatchingNonCancellation"))
        assertTrue(runner.contains("localizedVoiceRecoveryRetryStatus"))
        assertTrue(runner.contains("voiceRecoveryDecision("))
        assertTrue(runner.contains("runtime.streamUseCase.stream("))
        assertTrue(runner.contains("AgentStreamTurnUseCaseRequest("))
        assertTrue(runner.contains("selectedContact = selectedContact"))
        assertTrue(runner.contains("supersedesCommandId = supersedesCommandId"))
        assertTrue(runner.contains("callbacks.applyStreamEvent(sessionId, stepIndex, event)"))
        assertTrue(runner.contains("stream_completed_without_terminal"))
        assertTrue(runner.contains("callbacks.syncConversationSnapshotForVoiceRecovery("))
        assertTrue(runner.contains("callbacks.handleAgentStreamFailure(stepIndex, throwable, \"文字任务提交失败\")"))
        assertFalse(runner.contains("AgentInitialSkillLaunchStore.clear()"))
        assertFalse(runner.contains("AgentChatRequest("))
        assertFalse(runner.contains("AssistantViewModel"))
        assertFalse(runner.contains("AssistantRepository"))

        assertTrue(useCase.contains("AgentChatRequest("))
        assertTrue(useCase.contains("streamProvider = repository::agentChatStream"))
        assertTrue(useCase.lines().size <= 300)
    }

    @Test
    fun automaticNetworkRetryReusesOneIntentIdentityAndLatestAccount() = runBlocking {
        val captured = mutableListOf<AgentChatRequest>()
        val secondAttemptOpened = CompletableDeferred<Unit>()
        var state = Index9AssistantUiState(processingTurn = true)
        var currentUserId = "user-before-switch"
        val useCase = AgentStreamTurnUseCase { request ->
            captured += request
            if (captured.size == 1) {
                failingFlow(IllegalStateException("network timeout"))
            } else {
                secondAttemptOpened.complete(Unit)
                flowOf(AgentStreamEvent.Done)
            }
        }
        val runner = AgentStreamTurnRunner(
            runtime = AgentStreamTurnRuntime(
                scope = this,
                streamUseCase = useCase,
                stateProvider = { state },
                userContextProvider = { _, _ -> UserContextPayload() },
                isVoiceMode = { true },
                currentVoiceLanguage = { VoiceLanguage.Chinese },
                userIdProvider = { currentUserId },
                initialLaunchProvider = {
                    AgentInitialLaunch("restaurant_booking", "想订哪家餐厅？")
                },
            ),
            callbacks = AgentStreamTurnCallbacks(
                hasActiveBatchCallStream = { false },
                holdUiForActiveBatchCall = {},
                appendStreamingAssistantStep = { 0 },
                resetStreamingStepForRetry = {},
                updateState = { reducer -> state = reducer(state) },
                logAgentContext = { _, _, _ -> },
                applyStreamEvent = { _, _, _ -> },
                finalizeStreamingStep = {},
                syncConversationSnapshotForVoiceRecovery = { _, _ -> true },
                handleAgentStreamFailure = { _, error, _ -> throw error },
                logTts = {},
                logStream = {},
            ),
        )

        currentUserId = "user-after-switch"
        runner.start("session-1", "hello", null)
        withTimeout(2_000L) { secondAttemptOpened.await() }
        runner.cancelCurrentStream()

        assertEquals(2, captured.size)
        assertEquals(captured[0].commandId, captured[1].commandId)
        assertEquals(captured[0].idempotencyKey, captured[1].idempotencyKey)
        assertEquals(captured[0].traceId, captured[1].traceId)
        assertTrue(captured.all { it.userId == "user-after-switch" })
        assertTrue(captured.all { it.initialSkillId == "restaurant_booking" })
        assertTrue(captured.all { it.initialOpening == "想订哪家餐厅？" })
    }

    @Test
    fun structuredBackendFailureIsNotRetriedWithTerminatedIdentity() = runBlocking {
        val captured = mutableListOf<AgentChatRequest>()
        val failureHandled = CompletableDeferred<Throwable>()
        var state = Index9AssistantUiState(processingTurn = true)
        val failure = AgentStreamFailure(
            AgentStreamEvent.Err(
                message = "输入内容过长，请精简后重试",
                errorCode = "MODEL_CONTEXT_LIMIT",
                category = "MODEL",
                retryable = false
            )
        )
        val runner = AgentStreamTurnRunner(
            runtime = AgentStreamTurnRuntime(
                scope = this,
                streamUseCase = AgentStreamTurnUseCase { request ->
                    captured += request
                    failingFlow(failure)
                },
                stateProvider = { state },
                userContextProvider = { _, _ -> UserContextPayload() },
                isVoiceMode = { true },
                currentVoiceLanguage = { VoiceLanguage.Chinese },
                userIdProvider = { "user-1" },
                initialLaunchProvider = { null }
            ),
            callbacks = AgentStreamTurnCallbacks(
                hasActiveBatchCallStream = { false },
                holdUiForActiveBatchCall = {},
                appendStreamingAssistantStep = { 0 },
                resetStreamingStepForRetry = {},
                updateState = { reducer -> state = reducer(state) },
                logAgentContext = { _, _, _ -> },
                applyStreamEvent = { _, _, _ -> },
                finalizeStreamingStep = {},
                syncConversationSnapshotForVoiceRecovery = { _, _ -> true },
                handleAgentStreamFailure = { _, error, _ -> failureHandled.complete(error) },
                logTts = {},
                logStream = {}
            )
        )

        runner.start("session-1", "long request", null)
        assertEquals(failure, withTimeout(2_000L) { failureHandled.await() })
        runner.cancelCurrentStream()

        assertEquals(1, captured.size)
    }

    @Test
    fun supersedingTurnFinalizesTheCancelledTurnsOwnedStreamingStep() = runBlocking {
        val firstOpened = CompletableDeferred<Unit>()
        val secondOpened = CompletableDeferred<Unit>()
        val finalized = mutableListOf<Triple<Int, String, String>>()
        var nextStepIndex = 3
        val runner = AgentStreamTurnRunner(
            runtime = AgentStreamTurnRuntime(
                scope = this,
                streamUseCase = AgentStreamTurnUseCase { request ->
                    flow {
                        if (request.message == "first") {
                            firstOpened.complete(Unit)
                        } else {
                            secondOpened.complete(Unit)
                        }
                        kotlinx.coroutines.awaitCancellation()
                    }
                },
                stateProvider = { Index9AssistantUiState(processingTurn = true) },
                userContextProvider = { _, _ -> UserContextPayload() },
                isVoiceMode = { true },
                currentVoiceLanguage = { VoiceLanguage.Chinese },
                userIdProvider = { "user-1" },
                initialLaunchProvider = { null },
            ),
            callbacks = AgentStreamTurnCallbacks(
                hasActiveBatchCallStream = { false },
                holdUiForActiveBatchCall = {},
                appendStreamingAssistantStep = { nextStepIndex++ },
                resetStreamingStepForRetry = {},
                updateState = {},
                logAgentContext = { _, _, _ -> },
                applyStreamEvent = { _, _, _ -> },
                finalizeStreamingStep = {},
                syncConversationSnapshotForVoiceRecovery = { _, _ -> true },
                handleAgentStreamFailure = { _, error, _ -> throw error },
                logTts = {},
                logStream = {},
                closeCancelledStreamingStep = { stepIndex, sessionId, reason ->
                    finalized += Triple(stepIndex, sessionId, reason)
                },
            ),
        )

        runner.start("session-1", "first", null)
        withTimeout(2_000L) { firstOpened.await() }
        runner.start("session-1", "second", null)
        withTimeout(2_000L) { secondOpened.await() }

        assertEquals(
            listOf(Triple(3, "session-1", "superseded_by_new_turn")),
            finalized,
        )

        runner.cancelCurrentStream()
        assertEquals(
            Triple(4, "session-1", "explicit_interrupt"),
            finalized.last(),
        )
    }

    private fun failingFlow(throwable: Throwable): Flow<AgentStreamEvent> = flow {
        throw throwable
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
