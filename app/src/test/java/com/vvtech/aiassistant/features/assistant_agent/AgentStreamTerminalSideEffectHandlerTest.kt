package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamTerminalSideEffectHandlerTest {
    @Test
    fun callResultAppliesSideEffectsInStableOrderAndUpdatesConversationStatus() {
        val events = mutableListOf<String>()
        var uiState = Index9AssistantUiState(status = "old")
        var conversations = listOf(
            ConversationListItem(sessionId = "s1", title = "one", status = "RUNNING"),
            ConversationListItem(sessionId = "s2", title = "two", status = "RUNNING")
        )
        val handler = handler(
            events = events,
            uiStateSetter = { uiState = it },
            conversationsProvider = { conversations },
            conversationsSetter = { conversations = it }
        )

        handler.apply(
            AgentStreamTerminalSideEffectInput(
                plan = plan(
                    nextState = Index9AssistantUiState(status = "任务已完成"),
                    conversationSessionId = "s1",
                    conversationStatus = "COMPLETED"
                ),
                clearPrimarySummaryAction = true
            )
        )

        assertEquals(
            listOf(
                "clearPrimarySummaryAction",
                "clearPendingAiCallLaunch",
                "stopCallSessionPolling",
                "stopApiListening",
                "applyUiState:任务已完成",
                "setConversationList",
                "loadConversations"
            ),
            events
        )
        assertEquals("任务已完成", uiState.status)
        assertEquals(listOf("COMPLETED", "RUNNING"), conversations.map { it.status })
    }

    @Test
    fun skipsConversationStatusUpdateWhenSessionIdIsBlank() {
        val events = mutableListOf<String>()
        var conversations = listOf(
            ConversationListItem(sessionId = "s1", title = "one", status = "RUNNING")
        )
        val handler = handler(
            events = events,
            conversationsProvider = { conversations },
            conversationsSetter = { conversations = it }
        )

        handler.apply(
            AgentStreamTerminalSideEffectInput(
                plan = plan(conversationSessionId = "", conversationStatus = "COMPLETED"),
                clearPrimarySummaryAction = true
            )
        )

        assertFalse(events.contains("setConversationList"))
        assertEquals(listOf("RUNNING"), conversations.map { it.status })
        assertEquals("loadConversations", events.last())
    }

    @Test
    fun batchResultDoesNotClearPrimarySummaryAction() {
        val events = mutableListOf<String>()
        val handler = handler(events = events)

        handler.apply(
            AgentStreamTerminalSideEffectInput(
                plan = plan(conversationSessionId = "s1", conversationStatus = "INCOMPLETE"),
                clearPrimarySummaryAction = false
            )
        )

        assertFalse(events.contains("clearPrimarySummaryAction"))
        assertEquals("clearPendingAiCallLaunch", events.first())
        assertTrue(events.contains("stopCallSessionPolling"))
        assertTrue(events.contains("stopApiListening"))
        assertTrue(events.contains("loadConversations"))
    }

    @Test
    fun agentStreamHandlerDelegatesTerminalSideEffects() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val responseGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val responseHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseStateHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("AgentStreamTerminalSideEffectHandler"))
        assertTrue(responseGraph.contains("AgentStreamResponseStateHandler"))
        assertTrue(responseHandler.contains("AgentStreamTerminalSideEffectInput"))
        assertFalse(handler.contains("viewModel.conversationList.value = viewModel.conversationList.value.map"))
        assertFalse(handler.contains("viewModel.primarySummaryAction = null\n                viewModel.pendingAiCallLaunch = false"))
    }

    private fun sourceFile(path: String): File {
        return listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }

    private fun handler(
        events: MutableList<String>,
        uiStateSetter: (Index9AssistantUiState) -> Unit = {},
        conversationsProvider: () -> List<ConversationListItem> = {
            listOf(ConversationListItem(sessionId = "s1", title = "one", status = "RUNNING"))
        },
        conversationsSetter: (List<ConversationListItem>) -> Unit = {}
    ): AgentStreamTerminalSideEffectHandler {
        return AgentStreamTerminalSideEffectHandler(
            clearPrimarySummaryAction = { events += "clearPrimarySummaryAction" },
            clearPendingAiCallLaunch = { events += "clearPendingAiCallLaunch" },
            stopCallSessionPolling = { events += "stopCallSessionPolling" },
            stopApiListening = { events += "stopApiListening" },
            applyUiState = {
                events += "applyUiState:${it.status}"
                uiStateSetter(it)
            },
            conversationListProvider = conversationsProvider,
            setConversationList = {
                events += "setConversationList"
                conversationsSetter(it)
            },
            loadConversations = { events += "loadConversations" }
        )
    }

    private fun plan(
        nextState: Index9AssistantUiState = Index9AssistantUiState(status = "done"),
        conversationSessionId: String?,
        conversationStatus: String
    ): AgentStreamTerminalResponsePlan {
        return AgentStreamTerminalResponsePlan(
            nextState = nextState,
            statusText = nextState.status,
            conversationStatus = conversationStatus,
            conversationSessionId = conversationSessionId
        )
    }
}
