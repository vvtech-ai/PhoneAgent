package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionCandidateUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionGroupUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamDeviceContactSelectionHandlerTest {
    @Test
    fun pendingSelectionShowsUiWithoutSubmittingResult() = runBlocking {
        val selection = selection()
        val harness = Harness(scope = this)

        harness.handler.onResolved(
            results = emptyList(),
            pendingSelection = selection
        )

        assertEquals(selection, harness.state.agentDeviceContactSelection)
        assertFalse(harness.state.processingTurn)
        assertTrue(harness.events.any { it.startsWith("showSelection:") })
        assertNull(harness.capturedDeviceSubmit)
    }

    @Test
    fun resolvedResultsAppendEchoAndSubmitDeviceContactsWithVoiceChannel() = runBlocking {
        val results = listOf(mapOf("name" to "xiaoming", "status" to "RESOLVED"))
        val harness = Harness(scope = this, voiceMode = true)

        harness.handler.onResolved(
            results = results,
            echoText = "selected"
        )
        yield()

        assertTrue(harness.events.contains("user:selected"))
        assertTrue(harness.events.contains("placeholder:7"))
        assertEquals(
            CapturedDeviceSubmit("s1", "tool-1", "user-1", results, "voice", 7),
            harness.capturedDeviceSubmit
        )
        assertTrue(harness.events.contains("response:7:TEXT_REPLY"))
        assertNull(harness.state.agentPendingToolCallId)
        assertTrue(harness.state.processingTurn)
    }

    @Test
    fun invalidVoiceSelectionUpdatesRetryStateAndRestartsListening() = runBlocking {
        val harness = Harness(
            scope = this,
            voiceMode = true,
            state = Index9AssistantUiState(
                agentPendingToolCallId = "tool-1",
                agentDeviceContactSelection = selection(),
                listening = true,
                apiAsrListening = true,
                voiceConnecting = true
            )
        )

        val handled = harness.handler.tryHandleVoiceSelection("")

        assertTrue(handled)
        assertFalse(harness.state.listening)
        assertFalse(harness.state.apiAsrListening)
        assertFalse(harness.state.voiceConnecting)
        assertTrue(harness.state.status.isNotBlank())
        delay(350)
        assertTrue(harness.events.contains("startListening"))
    }

    @Test
    fun confirmAndCancelSubmitPolicyResults() = runBlocking {
        val candidate = DeviceContactSelectionCandidateUi(
            contactId = "c1",
            displayName = "Xiao Ming",
            phoneNumber = "10086",
            label = "mobile"
        )
        val harness = Harness(
            scope = this,
            state = Index9AssistantUiState(
                agentPendingToolCallId = "tool-1",
                agentDeviceContactSelection = selection(candidate)
            )
        )

        harness.handler.onConfirm(mapOf("xiaoming" to candidate))
        yield()

        val confirmSubmit = harness.capturedDeviceSubmit
        assertEquals("text", confirmSubmit?.channel)
        assertEquals("RESOLVED", confirmSubmit?.results?.firstOrNull { it["name"] == "xiaoming" }?.get("status"))
        assertTrue(harness.events.any { it.startsWith("user:") })

        harness.resetSubmitCapture(
            state = harness.state.copy(
                agentPendingToolCallId = "tool-2",
                agentDeviceContactSelection = selection(candidate)
            )
        )
        harness.handler.onCancel()
        yield()

        val cancelSubmit = harness.capturedDeviceSubmit
        assertEquals("tool-2", cancelSubmit?.pendingToolCallId)
        assertEquals("CANCELLED", cancelSubmit?.results?.firstOrNull { it["name"] == "xiaoming" }?.get("status"))
        assertTrue(harness.events.any { it.startsWith("user:") })
    }

    @Test
    fun agentStreamHandlerDelegatesDeviceContactSelectionFlow() {
        val agentStreamHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val deviceHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamDeviceContactSelectionHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(agentStreamHandler.contains("actionGraph.onAgentLookupDeviceContactsResolved("))
        assertTrue(agentStreamHandler.contains("actionGraph.tryHandleAgentDeviceContactVoiceSelection(rawText)"))
        assertTrue(actionGraph.contains("AgentStreamDeviceContactSelectionHandler("))
        assertTrue(actionGraph.contains("deviceContactSelectionHandler.onResolved("))
        assertTrue(actionGraph.contains("deviceContactSelectionHandler.tryHandleVoiceSelection(rawText)"))
        assertFalse(agentStreamHandler.contains("AgentDeviceContactVoiceSelectionResult"))
        assertFalse(agentStreamHandler.contains("restartContactSelectionListeningIfNeeded"))
        assertFalse(agentStreamHandler.contains("applyDeviceContactSelectionRetryStatus"))

        assertTrue(deviceHandler.contains("AgentDeviceContactVoiceSelectionResult"))
        assertTrue(deviceHandler.contains("delay(300)"))
        assertFalse(deviceHandler.contains("AssistantViewModel"))
    }

    private class Harness(
        scope: CoroutineScope,
        var state: Index9AssistantUiState = Index9AssistantUiState(agentPendingToolCallId = "tool-1"),
        private val sessionId: String? = "s1",
        private val voiceMode: Boolean = false
    ) {
        val events = mutableListOf<String>()
        var capturedDeviceSubmit: CapturedDeviceSubmit? = null

        private val submitter = AgentStreamContactLookupResultSubmitter(
            scope = scope,
            lookupResultUseCase = AgentStreamContactLookupResultUseCase(
                contactLookupResultProvider = { error("contact provider should not be called") },
                deviceContactsLookupResultProvider = { request ->
                    capturedDeviceSubmit = CapturedDeviceSubmit(
                        sessionId = request.sessionId,
                        pendingToolCallId = request.pendingToolCallId,
                        userId = request.userId,
                        results = request.results,
                        channel = request.channel,
                        placeholderIndex = 7
                    )
                    AgentChatResponse(sessionId = request.sessionId, type = "TEXT_REPLY", text = "ok")
                }
            ),
            responseConsumer = { placeholderIndex, response ->
                events += "response:$placeholderIndex:${response.type}"
            },
            failureConsumer = { _, _, _ -> error("failure should not be called") }
        )

        val handler = AgentStreamDeviceContactSelectionHandler(
            runtime = AgentStreamDeviceContactSelectionRuntime(
                stateProvider = { state },
                sessionIdProvider = { sessionId },
                isVoiceMode = { voiceMode },
                scope = scope,
                userIdProvider = { "user-1" }
            ),
            callbacks = AgentStreamDeviceContactSelectionCallbacks(
                clearWithoutPendingTool = {
                    events += "clearWithoutPending"
                    state = state.copy(
                        agentLookupDeviceContactsInFlight = false,
                        agentDeviceContactSelection = null,
                        processingTurn = false
                    )
                },
                showSelection = { selection, status ->
                    events += "showSelection:$status"
                    state = state.copy(
                        processingTurn = false,
                        agentLookupDeviceContactsInFlight = false,
                        agentDeviceContactSelection = selection,
                        status = status
                    )
                },
                prepareSubmitting = { status ->
                    events += "prepare:$status"
                    state = state.copy(
                        processingTurn = true,
                        error = null,
                        agentPendingToolCallId = null,
                        agentLookupDeviceContactsRequest = null,
                        agentLookupDeviceContactsInFlight = false,
                        agentDeviceContactSelection = null,
                        status = status
                    )
                },
                appendUserStep = { text -> events += "user:$text" },
                appendAssistantPlaceholder = {
                    events += "placeholder:7"
                    7
                },
                updateState = { reducer ->
                    state = reducer(state)
                    events += "state:${state.status}"
                },
                startApiListening = {
                    events += "startListening"
                }
            ),
            submitter = submitter
        )

        fun resetSubmitCapture(state: Index9AssistantUiState) {
            this.state = state
            capturedDeviceSubmit = null
        }
    }

    private data class CapturedDeviceSubmit(
        val sessionId: String,
        val pendingToolCallId: String,
        val userId: String,
        val results: List<Map<String, Any?>>,
        val channel: String?,
        val placeholderIndex: Int
    )

    private companion object {
        fun selection(
            candidate: DeviceContactSelectionCandidateUi = DeviceContactSelectionCandidateUi(
                contactId = "c1",
                displayName = "Xiao Ming",
                phoneNumber = "10086",
                label = "mobile"
            )
        ): DeviceContactSelectionUiState {
            return DeviceContactSelectionUiState(
                pendingToolCallId = "tool-1",
                groups = listOf(
                    DeviceContactSelectionGroupUi(
                        name = "xiaoming",
                        candidates = listOf(candidate)
                    )
                ),
                preResolvedResults = listOf(mapOf("name" to "pre", "status" to "RESOLVED"))
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
