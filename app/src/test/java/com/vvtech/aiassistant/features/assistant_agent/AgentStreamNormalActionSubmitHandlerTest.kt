package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamNormalActionSubmitHandlerTest {
    @Test
    fun submitRunsSideEffectsInStableOrderAndBuildsRequest() {
        val operations = mutableListOf<String>()
        var state = Index9AssistantUiState(status = "空闲", processingTurn = false)
        var capturedRequest: AgentStreamActionSubmitRequest? = null
        var capturedBeforeRecover: (() -> Unit)? = null
        var currentUserId = "user-before-switch"
        val beforeRecover = { operations += "recover" }
        val handler = AgentStreamNormalActionSubmitHandler(
            appendUserStep = { text -> operations += "echo:$text" },
            updateUiState = { reducer ->
                operations += "state"
                state = reducer(state)
            },
            appendAssistantPlaceholder = {
                operations += "placeholder"
                42
            },
            submitAction = { request, recover ->
                operations += "submit"
                capturedRequest = request
                capturedBeforeRecover = recover
            },
            channelProvider = {
                operations += "channel"
                "voice"
            },
            userIdProvider = { currentUserId }
        )

        currentUserId = "user-after-switch"
        handler.submit(
            AgentStreamNormalActionSubmitInput(
                sessionId = "session-1",
                actionDraft = AgentStreamActionDraft(
                    actionId = "select_option",
                    actionPayload = mapOf("optionId" to "a"),
                    echoText = "已选：北海渔村"
                ),
                stateReducer = { it.copy(processingTurn = true, status = "AI处理中", error = null) },
                contextReason = "agent_select_option",
                logAction = "select_option",
                failureMessage = "选择失败",
                beforeRecover = beforeRecover
            )
        )

        assertEquals(listOf("echo:已选：北海渔村", "state", "placeholder", "channel", "submit"), operations)
        assertTrue(state.processingTurn)
        assertEquals("AI处理中", state.status)
        val request = requireNotNull(capturedRequest)
        assertEquals("session-1", request.sessionId)
        assertEquals("select_option", request.actionId)
        assertEquals(mapOf("optionId" to "a"), request.actionPayload)
        assertEquals("agent_select_option", request.contextReason)
        assertEquals("select_option", request.logAction)
        assertEquals("voice", request.channel)
        assertEquals("user-after-switch", request.userId)
        assertEquals(42, request.placeholderIndex)
        assertEquals("选择失败", request.failureMessage)
        assertSame(beforeRecover, capturedBeforeRecover)

        assertNotNull(capturedBeforeRecover)
        capturedBeforeRecover?.invoke()
        assertEquals("recover", operations.last())
    }
}
