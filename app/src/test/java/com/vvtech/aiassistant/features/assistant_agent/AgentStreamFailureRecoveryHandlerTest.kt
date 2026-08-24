package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamFailureRecoveryHandlerTest {
    @Test
    fun nonVoiceStreamFailureFinalizesAndAppliesExecutionError() {
        val harness = Harness(voiceMode = false)

        harness.handler.handleStreamFailure(0, RuntimeException("plain failure"), "fallback")

        assertEquals(
            listOf("cancelProgress", "finalize:0", "state:plain failure:false", "release:0"),
            harness.events,
        )
        assertEquals("EXECUTION_ERROR", harness.state.taskStatus)
        assertEquals("plain failure", harness.state.error)
        assertFalse(harness.steps[0].streaming)
    }

    @Test
    fun sensitiveNetworkFailureAbortsPlaceholderAndAppliesNetworkTaskError() {
        val harness = Harness(voiceMode = false)

        harness.handler.handleStreamFailure(0, RuntimeException("failed to connect 10.0.0.1 port 8080"), "fallback")

        assertEquals(
            listOf(
                "cancelProgress",
                "mutate:（网络连接异常，请检查网络后重试）",
                "finalize:0",
                "network:failed to connect 10.0.0.1 port 8080",
                "release:0",
            ),
            harness.events
        )
    }

    @Test
    fun structuredModelFailureIsNotMisclassifiedByDisplayMessage() {
        val harness = Harness(voiceMode = false)
        val failure = AgentStreamFailure(
            AgentStreamEvent.Err(
                message = "服务暂时不可用，请稍后再试",
                errorCode = "MODEL_BAD_REQUEST",
                category = "MODEL",
                retryable = false,
                recoveryAction = "REBUILD_CONTEXT"
            )
        )

        harness.handler.handleStreamFailure(0, failure, "fallback")

        assertFalse(harness.events.any { it.startsWith("network:") })
        assertEquals("服务暂时不可用，请稍后再试", harness.state.error)
    }

    @Test
    fun structuredNetworkFailureUsesNetworkRecoveryWithoutKeywordMatching() {
        val harness = Harness(voiceMode = false)
        val failure = AgentStreamFailure(
            AgentStreamEvent.Err(
                message = "请求失败",
                errorCode = "NETWORK_TRANSPORT",
                category = "NETWORK",
                retryable = true,
                recoveryAction = "RETRY"
            )
        )

        harness.handler.handleStreamFailure(0, failure, "fallback")

        assertTrue(harness.events.any { it == "network:请求失败" })
    }

    @Test
    fun voiceNetworkFailureFreezesTheRecoverableTurnBeforeApplyingNetworkState() {
        val harness = Harness(voiceMode = true)

        harness.handler.handleStreamFailure(
            0,
            RuntimeException("failed to connect 10.0.0.1 port 8080"),
            "fallback",
        )

        assertTrue(harness.events.contains("freezeRecoverableTurn"))
        assertTrue(
            harness.events.indexOf("freezeRecoverableTurn") <
                harness.events.indexOfFirst { it.startsWith("network:") }
        )
    }

    @Test
    fun activeBatchFailureAppliesSyncPendingAndRefreshesConversations() {
        val harness = Harness(activeBatch = true)

        harness.handler.handleStreamFailure(0, RuntimeException("batch failed"), "fallback")

        assertEquals(
            listOf(
                "cancelProgress",
                "finalize:0",
                "clearBatch",
                "stopApi",
                "state:多路外呼结果同步中，请稍后刷新:false",
                "loadConversations",
                "release:0",
            ),
            harness.events
        )
        assertEquals("多路外呼结果同步中，请稍后刷新", harness.state.status)
    }

    @Test
    fun completedCallOutcomeFailureKeepsTaskActiveAndRefreshesConversations() {
        val harness = Harness(voiceMode = true)
        harness.state = harness.state.copy(
            processingTurn = true,
            taskStatus = "ACTIVE",
            status = "正在确认通话结果"
        )

        harness.handler.handleStreamFailure(0, RuntimeException("服务暂时不可用，请稍后再试"), "fallback")

        assertEquals("ACTIVE", harness.state.taskStatus)
        assertEquals("通话已结束，结果同步中，请稍后刷新", harness.state.status)
        assertEquals(null, harness.state.error)
        assertFalse(harness.events.any { it.startsWith("network:") || it.startsWith("markRecovery:") })
        assertTrue(harness.events.contains("syncTimeline"))
        assertTrue(harness.events.contains("loadConversations"))
    }

    @Test
    fun backgroundedCompletedCallOutcomeFailureStillRefreshesDurableResult() {
        val harness = Harness(voiceMode = true)
        harness.state = harness.state.copy(
            processingTurn = false,
            taskStatus = "ACTIVE",
            status = "已暂停，返回后可继续",
            callPageData = harness.state.callPageData.copy(status = callOutcomePendingStatusText())
        )

        harness.handler.handleStreamFailure(0, RuntimeException("Software caused connection abort"), "fallback")

        assertEquals("ACTIVE", harness.state.taskStatus)
        assertEquals(callOutcomeSyncPendingStatusText(), harness.state.status)
        assertFalse(harness.events.any { it.startsWith("markRecovery:") || it.startsWith("startApi:") })
        assertTrue(harness.events.contains("syncTimeline"))
        assertTrue(harness.events.contains("loadConversations"))
    }

    @Test
    fun activeSingleCallFailureKeepsCallContextAndDoesNotResumeListening() {
        val harness = Harness(voiceMode = true)
        harness.state = harness.state.copy(
            processingTurn = true,
            taskStatus = "ACTIVE",
            showAiCallPage = true,
            currentCallId = "call-active"
        )

        harness.handler.handleStreamFailure(0, RuntimeException("通话执行失败，请稍后再试"), "fallback")

        assertEquals("ACTIVE", harness.state.taskStatus)
        assertEquals("正在确认通话状态", harness.state.status)
        assertEquals("call-active", harness.state.currentCallId)
        assertTrue(harness.state.showAiCallPage)
        assertTrue(harness.events.contains("stopApi"))
        assertTrue(harness.events.contains("syncTimeline"))
        assertTrue(harness.events.contains("loadConversations"))
        assertFalse(harness.events.any { it.startsWith("markRecovery:") || it.startsWith("startApi:") })
    }

    @Test
    fun voiceFailureClearsPlaceholderMarksRecoveryAndStartsListening() {
        val harness = Harness(voiceMode = true)

        harness.handler.handleStreamFailure(0, RuntimeException("voice failed"), "fallback")

        assertEquals(
            listOf(
                "cancelProgress",
                "state:点击麦克风，开始描述任务:false",
                "markRecovery:EXECUTION_ERROR",
                "state:语音已恢复，可以继续说:false",
                "startApi:agent_transport_failure_recovery",
                "release:0",
            ),
            harness.events
        )
        assertTrue(harness.state.clarificationSteps.isEmpty())
    }

    @Test
    fun voiceRecoverySuspendsWhenCallAudioSuppressed() {
        val harness = Harness(voiceMode = true, suppressed = true)

        harness.handler.resumeListeningAfterAgentRecovery()

        assertEquals(listOf("suspend:agent_recovery_call_active"), harness.events)
    }

    @Test
    fun actionFailureRunsBeforeRecoverBeforeHandlingFailure() {
        val harness = Harness(voiceMode = false)

        harness.handler.handleActionFailure(
            stepIndex = 0,
            throwable = RuntimeException("action failed"),
            fallback = "fallback",
            beforeRecover = { harness.events += "before" }
        )

        assertEquals("before", harness.events.first())
        assertTrue(harness.events.contains("state:action failed:false"))
    }

    @Test
    fun retryResetReplacesStreamingStepWithFreshRetryStep() {
        val harness = Harness(nowMs = 123L)

        harness.handler.resetStreamingStepForRetry(0)

        assertEquals(listOf("mutate:"), harness.events)
        assertEquals(123L, harness.steps[0].thinkingStartedAt)
        assertTrue(harness.steps[0].streaming)
    }

    @Test
    fun agentStreamHandlerDelegatesFailureRecovery() {
        val agentStreamHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val responseGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val recoveryHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamFailureRecoveryHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(agentStreamHandler.contains("AgentStreamFailureRecoveryHandler("))
        assertTrue(agentStreamHandler.contains("failureRecoveryHandler::handleStreamFailure"))
        assertTrue(actionGraph.contains("failureRecoveryHandler.handleActionFailure"))
        assertTrue(agentStreamHandler.contains("failureRecoveryHandler::resetStreamingStepForRetry"))
        assertTrue(responseGraph.contains("failureRecoveryHandler::resumeListeningAfterAgentRecovery"))
        assertFalse(agentStreamHandler.contains("private fun abortPlaceholder("))
        assertFalse(agentStreamHandler.contains("private fun handleAgentStreamFailure("))
        assertFalse(agentStreamHandler.contains("private fun handleAgentActionFailure("))
        assertFalse(agentStreamHandler.contains("private fun clearRecoverablePlaceholder("))
        assertFalse(agentStreamHandler.contains("private fun resetStreamingStepForRetry("))
        assertFalse(agentStreamHandler.contains("private fun resumeListeningAfterAgentRecovery("))
        assertFalse(agentStreamHandler.contains("containsSensitiveNetworkError(throwable.message)"))
        assertFalse(agentStreamHandler.contains("AgentStreamErrorUiStateReducer.applyExecutionError"))
        assertFalse(agentStreamHandler.contains("AgentStreamPlaceholderStepReducer.clearRecoverablePlaceholder"))

        assertTrue(recoveryHandler.contains("containsTransportNetworkError(throwable.message)"))
        assertTrue(recoveryHandler.contains("AgentStreamErrorUiStateReducer.applyExecutionError"))
        assertFalse(recoveryHandler.contains("AssistantViewModel"))
        assertFalse(recoveryHandler.contains("AssistantRepository"))
    }

    private class Harness(
        private val voiceMode: Boolean = false,
        private var activeBatch: Boolean = false,
        private val suppressed: Boolean = false,
        private val nowMs: Long = 1L
    ) {
        val events = mutableListOf<String>()
        val steps = mutableListOf(step())
        var state = Index9AssistantUiState(clarificationSteps = steps)

        val handler = AgentStreamFailureRecoveryHandler(
            runtime = AgentStreamFailureRecoveryRuntime(
                stateProvider = { state },
                isVoiceMode = { voiceMode },
                currentVoiceLanguage = { VoiceLanguage.Chinese },
                hasActiveBatchCallStream = { activeBatch },
                isOutboundCallAudioSuppressed = { suppressed },
                batchSyncPendingStatusText = { "多路外呼结果同步中，请稍后刷新" },
                nowMs = { nowMs }
            ),
            callbacks = AgentStreamFailureRecoveryCallbacks(
                cancelTextProcessingStatusProgress = { events += "cancelProgress" },
                mutateStep = { index, mutator ->
                    steps[index] = mutator(steps[index])
                    state = state.copy(clarificationSteps = steps)
                    events += "mutate:${steps[index].text}"
                },
                finalizeStep = { index ->
                    steps[index] = steps[index].copy(streaming = false)
                    state = state.copy(clarificationSteps = steps)
                    events += "finalize:$index"
                },
                updateState = { reducer ->
                    state = reducer(state)
                    events += "state:${state.status}:${state.processingTurn}"
                },
                clearActiveBatchCallState = {
                    activeBatch = false
                    events += "clearBatch"
                },
                stopApiListening = { events += "stopApi" },
                syncCurrentTimeline = { events += "syncTimeline" },
                loadConversations = { events += "loadConversations" },
                applyNetworkTaskErrorState = { events += "network:$it" },
                markTaskErrorRecoveryInProgress = { events += "markRecovery:$it" },
                startApiListening = { trigger -> events += "startApi:$trigger" },
                suspendDialogAudioForCall = { events += "suspend:$it" },
                releaseStreamOwnership = { events += "release:$it" },
                onRecoverableVoiceTurnNetworkFailure = { events += "freezeRecoverableTurn" },
            )
        )
    }

    private companion object {
        fun step(): ClarificationStep {
            return ClarificationStep(
                role = VoiceRole.Assistant,
                text = "",
                status = "",
                streaming = true
            )
        }

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
