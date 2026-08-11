package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.model.UserContextPayload
import java.io.File
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamActionSubmitterTest {

    @Test
    fun submitBuildsRequestAndDispatchesEvents() = runBlocking {
        var capturedRequest: AgentChatRequest? = null
        val logged = mutableListOf<String>()
        val eventSessions = mutableListOf<String>()
        val events = mutableListOf<AgentStreamEvent>()
        val submitter = AgentStreamActionSubmitter(
            scope = this,
            streamUseCase = AgentStreamActionSubmitUseCase(
                streamProvider = { request ->
                    capturedRequest = request
                    flowOf(AgentStreamEvent.TextDelta("ok"))
                }
            ),
            userContextProvider = { reason -> UserContextPayload(city = reason) },
            contextLogger = { action, sessionId, context ->
                logged += "$action|$sessionId|${context.city}"
            },
            eventConsumer = { sessionId, placeholderIndex, event ->
                eventSessions += sessionId
                assertEquals(7, placeholderIndex)
                events += event
            },
            failureConsumer = { _, _, _, _, _ -> error("failure should not be called") }
        )

        submitter.submit(
            AgentStreamActionSubmitRequest(
                sessionId = "s1",
                actionId = "select_option",
                actionPayload = mapOf("optionId" to "a"),
                contextReason = "agent_select_option",
                logAction = "select_option",
                channel = "voice",
                userId = "u1",
                placeholderIndex = 7,
                failureMessage = "选择失败"
            )
        ).join()

        assertEquals("s1", capturedRequest?.sessionId)
        assertEquals("select_option", capturedRequest?.actionId)
        assertEquals(mapOf("optionId" to "a"), capturedRequest?.actionPayload)
        assertEquals("agent_select_option", capturedRequest?.userContext?.city)
        assertEquals("voice", capturedRequest?.channel)
        assertEquals("u1", capturedRequest?.userId)
        assertTrue(capturedRequest?.commandId?.isNotBlank() == true)
        assertTrue(capturedRequest?.idempotencyKey?.startsWith("conv:v1:command:") == true)
        assertTrue(capturedRequest?.traceId?.isNotBlank() == true)
        assertEquals(listOf("select_option|s1|agent_select_option"), logged)
        assertEquals(listOf("s1"), eventSessions)
        assertEquals(listOf(AgentStreamEvent.TextDelta("ok")), events)
    }

    @Test
    fun submitCompletedWithoutTerminalInvokesRecoveryCallback() = runBlocking {
        val events = mutableListOf<AgentStreamEvent>()
        val recovered = mutableListOf<AgentStreamActionSubmitRequest>()
        val submitter = AgentStreamActionSubmitter(
            scope = this,
            streamUseCase = AgentStreamActionSubmitUseCase(
                streamProvider = {
                    flowOf(
                        AgentStreamEvent.TextDelta("calling"),
                        AgentStreamEvent.Done
                    )
                }
            ),
            userContextProvider = { UserContextPayload() },
            contextLogger = { _, _, _ -> },
            eventConsumer = { sessionId, placeholderIndex, event ->
                assertEquals("call-session", sessionId)
                assertEquals(9, placeholderIndex)
                events += event
            },
            failureConsumer = { _, _, _, _, _ -> error("failure should not be called") },
            completedWithoutTerminalConsumer = { request -> recovered += request }
        )

        submitter.submit(
            AgentStreamActionSubmitRequest(
                sessionId = "call-session",
                actionId = "confirm_call",
                contextReason = "agent_confirm_call",
                logAction = "confirm_call",
                channel = "voice",
                userId = "default-user",
                placeholderIndex = 9,
                failureMessage = "拨打失败"
            )
        ).join()

        assertEquals(listOf(AgentStreamEvent.TextDelta("calling"), AgentStreamEvent.Done), events)
        assertEquals(1, recovered.size)
        assertEquals("call-session", recovered.single().sessionId)
        assertEquals("confirm_call", recovered.single().actionId)
        assertEquals(9, recovered.single().placeholderIndex)
    }

    @Test
    fun submitRoutesFailureThroughBeforeRecoverAndFailureConsumer() = runBlocking {
        val failure = IllegalStateException("boom")
        var beforeRecoverCalled = false
        var capturedThrowable: Throwable? = null
        var capturedMessage: String? = null
        var capturedBeforeRecover: (() -> Unit)? = null
        val submitter = AgentStreamActionSubmitter(
            scope = this,
            streamUseCase = AgentStreamActionSubmitUseCase(
                streamProvider = { failingFlow(failure) }
            ),
            userContextProvider = { UserContextPayload() },
            contextLogger = { _, _, _ -> },
            eventConsumer = { _, _, _ -> },
            failureConsumer = { sessionId, placeholderIndex, throwable, message, beforeRecover ->
                assertEquals("s1", sessionId)
                assertEquals(3, placeholderIndex)
                capturedThrowable = throwable
                capturedMessage = message
                capturedBeforeRecover = beforeRecover
            }
        )

        submitter.submit(
            AgentStreamActionSubmitRequest(
                sessionId = "s1",
                actionId = "submit_document",
                contextReason = "agent_submit_document",
                logAction = "submit_document",
                channel = "text",
                userId = "u1",
                placeholderIndex = 3,
                failureMessage = "文档结果提交失败"
            ),
            onFailureBeforeHandle = { _ -> beforeRecoverCalled = true },
            beforeRecover = { beforeRecoverCalled = beforeRecoverCalled && true }
        ).join()

        assertTrue(beforeRecoverCalled)
        assertSame(failure, capturedThrowable)
        assertEquals("文档结果提交失败", capturedMessage)
        capturedBeforeRecover?.invoke()
        assertTrue(beforeRecoverCalled)
    }

    @Test
    fun submitConfirmCallAllowsNullPayloadAndPreservesFailureOrder() = runBlocking {
        val failure = IllegalStateException("boom")
        var capturedRequest: AgentChatRequest? = null
        val logged = mutableListOf<String>()
        val order = mutableListOf<String>()
        val submitter = AgentStreamActionSubmitter(
            scope = this,
            streamUseCase = AgentStreamActionSubmitUseCase(
                streamProvider = { request ->
                    capturedRequest = request
                    failingFlow(failure)
                }
            ),
            userContextProvider = { reason -> UserContextPayload(city = reason) },
            contextLogger = { action, sessionId, context ->
                logged += "$action|$sessionId|${context.city}"
            },
            eventConsumer = { _, _, _ -> error("event should not be called") },
            failureConsumer = { sessionId, placeholderIndex, throwable, message, beforeRecover ->
                order += "failure"
                assertEquals("call-session", sessionId)
                assertEquals(5, placeholderIndex)
                assertSame(failure, throwable)
                assertEquals("拨打失败", message)
                beforeRecover?.invoke()
            }
        )

        submitter.submit(
            AgentStreamActionSubmitRequest(
                sessionId = "call-session",
                actionId = "confirm_call",
                contextReason = "agent_confirm_call",
                logAction = "confirm_call",
                channel = "voice",
                userId = "default-user",
                placeholderIndex = 5,
                failureMessage = "拨打失败"
            ),
            onFailureBeforeHandle = { throwable -> order += "before:${throwable.message}" },
            beforeRecover = { order += "recover" }
        ).join()

        assertEquals("call-session", capturedRequest?.sessionId)
        assertEquals("confirm_call", capturedRequest?.actionId)
        assertNull(capturedRequest?.actionPayload)
        assertEquals("agent_confirm_call", capturedRequest?.userContext?.city)
        assertEquals("voice", capturedRequest?.channel)
        assertEquals("default-user", capturedRequest?.userId)
        assertTrue(capturedRequest?.commandId?.isNotBlank() == true)
        assertTrue(capturedRequest?.idempotencyKey?.startsWith("conv:v1:command:") == true)
        assertTrue(capturedRequest?.traceId?.isNotBlank() == true)
        assertEquals(listOf("confirm_call|call-session|agent_confirm_call"), logged)
        assertEquals(listOf("before:boom", "failure", "recover"), order)
    }

    @Test
    fun requestConstructionAndActionStreamProviderLiveInUseCase() {
        val host = File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
            .readText(Charsets.UTF_8)
        val actionGraph =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val submitter =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionSubmitter.kt")
                .readText(Charsets.UTF_8)
        val useCase =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionSubmitUseCase.kt")
                .readText(Charsets.UTF_8)

        assertTrue(host.contains("AgentStreamActionRuntimeGraph("))
        assertTrue(host.contains("applyStreamEvent = ::applyStreamEventIfCurrentSession"))
        assertTrue(submitter.contains("eventConsumer(request.sessionId, request.placeholderIndex, event)"))
        assertTrue(actionGraph.contains("streamUseCase = AgentStreamActionSubmitUseCase(repository)"))
        assertTrue(actionGraph.contains("completedWithoutTerminalConsumer = ::handleActionCompletedWithoutTerminal"))
        assertTrue(actionGraph.contains("viewModel.syncConversationSnapshotForVoiceRecovery("))
        assertFalse(
            actionGraph.contains(
                "AgentStreamActionSubmitter(\n        scope = viewModel.viewModelScope,\n        streamProvider = repository::agentChatStream"
            )
        )
        assertFalse(submitter.contains("AgentChatRequest("))
        assertTrue(submitter.contains("streamUseCase.stream(request, userContext)"))
        assertTrue(useCase.contains("AgentChatRequest("))
        assertTrue(useCase.contains("streamProvider = repository::agentChatStream"))
        assertTrue(useCase.lines().size <= 300)
    }

    private fun failingFlow(throwable: Throwable): Flow<AgentStreamEvent> = flow {
        throw throwable
    }
}
