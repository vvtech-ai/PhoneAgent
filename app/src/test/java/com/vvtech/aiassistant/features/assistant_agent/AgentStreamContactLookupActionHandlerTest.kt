package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamContactLookupActionHandlerTest {
    @Test
    fun resultPreparesStateAndSubmitsContactLookupRequestWithoutUserEcho() = runBlocking {
        val payload = mapOf("found" to true, "displayName" to "Xiao Ming", "phoneNumber" to "10086")
        val harness = Harness(scope = this)

        harness.handler.onResult(payload)
        yield()

        assertFalse(harness.events.any { it.startsWith("user:") })
        assertTrue(harness.events.contains("placeholder:5"))
        assertEquals(
            CapturedContactSubmit(
                sessionId = "s1",
                pendingToolCallId = "tool-1",
                userId = "user-1",
                result = payload,
                placeholderIndex = 5
            ),
            harness.capturedSubmit
        )
        assertTrue(harness.events.contains("response:5:TEXT_REPLY"))
        assertTrue(harness.state.processingTurn)
        assertNull(harness.state.agentPendingToolCallId)
        assertNull(harness.state.agentLookupContactPhone)
        assertFalse(harness.state.agentLookupContactInFlight)
        assertEquals("AI处理中", harness.state.status)
    }

    @Test
    fun missingSessionSkipsStateChangesAndSubmit() = runBlocking {
        val harness = Harness(
            scope = this,
            sessionId = null,
            state = Index9AssistantUiState(
                agentPendingToolCallId = "tool-1",
                agentLookupContactPhone = "10086",
                agentLookupContactInFlight = true
            )
        )

        harness.handler.onResult(mapOf("found" to false))
        yield()

        assertTrue(harness.events.isEmpty())
        assertNull(harness.capturedSubmit)
        assertEquals("tool-1", harness.state.agentPendingToolCallId)
        assertTrue(harness.state.agentLookupContactInFlight)
    }

    @Test
    fun missingPendingToolClearsLookupStateWithoutSubmitting() = runBlocking {
        val harness = Harness(
            scope = this,
            state = Index9AssistantUiState(
                agentPendingToolCallId = null,
                agentLookupContactPhone = "10086",
                agentLookupContactInFlight = true,
                processingTurn = true
            )
        )

        harness.handler.onResult(mapOf("found" to false))
        yield()

        assertTrue(harness.events.contains("clearWithoutPending"))
        assertNull(harness.capturedSubmit)
        assertNull(harness.state.agentLookupContactPhone)
        assertFalse(harness.state.agentLookupContactInFlight)
        assertFalse(harness.state.processingTurn)
    }

    @Test
    fun agentStreamHandlerDelegatesContactLookupActionFlow() {
        val host = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
            .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val lookupHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamContactLookupActionHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(host.contains("actionGraph.onAgentLookupContactResult(payload)"))
        assertTrue(actionGraph.contains("AgentStreamContactLookupActionHandler("))
        assertTrue(actionGraph.contains("contactLookupActionHandler.onResult(payload)"))
        assertFalse(host.contains("AgentStreamUserActionPolicy.lookupContactEcho(payload)"))
        assertFalse(host.contains("AgentContactLookupResultSubmitRequest("))
        assertFalse(host.contains("prepareLookupContactResultSubmitting(\"AI处理中\")"))

        assertTrue(lookupHandler.contains("AgentContactLookupResultSubmitRequest("))
        assertFalse(lookupHandler.contains("AssistantViewModel"))
    }

    private class Harness(
        scope: CoroutineScope,
        var state: Index9AssistantUiState = Index9AssistantUiState(
            agentPendingToolCallId = "tool-1",
            agentLookupContactPhone = "10086",
            agentLookupContactInFlight = true
        ),
        private val sessionId: String? = "s1"
    ) {
        val events = mutableListOf<String>()
        var capturedSubmit: CapturedContactSubmit? = null

        private val submitter = AgentStreamContactLookupResultSubmitter(
            scope = scope,
            lookupResultUseCase = AgentStreamContactLookupResultUseCase(
                contactLookupResultProvider = { request ->
                    capturedSubmit = CapturedContactSubmit(
                        sessionId = request.sessionId,
                        pendingToolCallId = request.pendingToolCallId,
                        userId = request.userId,
                        result = request.result,
                        placeholderIndex = 5
                    )
                    AgentChatResponse(sessionId = request.sessionId, type = "TEXT_REPLY", text = "ok")
                },
                deviceContactsLookupResultProvider = { error("device provider should not be called") }
            ),
            responseConsumer = { placeholderIndex, response ->
                events += "response:$placeholderIndex:${response.type}"
            },
            failureConsumer = { _, _, _ -> error("failure should not be called") }
        )

        val handler = AgentStreamContactLookupActionHandler(
            runtime = AgentStreamContactLookupActionRuntime(
                stateProvider = { state },
                sessionIdProvider = { sessionId },
                userIdProvider = { "user-1" }
            ),
            callbacks = AgentStreamContactLookupActionCallbacks(
                clearWithoutPendingTool = {
                    events += "clearWithoutPending"
                    state = state.copy(
                        agentLookupContactPhone = null,
                        agentLookupContactInFlight = false,
                        processingTurn = false
                    )
                },
                prepareSubmitting = { status ->
                    events += "prepare:$status"
                    state = state.copy(
                        processingTurn = true,
                        error = null,
                        agentPendingToolCallId = null,
                        agentLookupContactPhone = null,
                        agentLookupContactInFlight = false,
                        status = status
                    )
                },
                appendAssistantPlaceholder = {
                    events += "placeholder:5"
                    5
                }
            ),
            submitter = submitter
        )
    }

    private data class CapturedContactSubmit(
        val sessionId: String,
        val pendingToolCallId: String,
        val userId: String,
        val result: Map<String, Any?>,
        val placeholderIndex: Int
    )

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
