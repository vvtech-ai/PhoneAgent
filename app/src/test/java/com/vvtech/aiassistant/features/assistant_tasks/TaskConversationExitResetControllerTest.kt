package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskConversationExitResetControllerTest {
    @Test
    fun pauseAndResetUsesTaskIdFallbackAndPersistsExecutionErrorBeforeReload() {
        val events = mutableListOf<String>()
        val uiState = Index9AssistantUiState(
            taskId = " task-1 ",
            taskStatus = "NETWORK_ERROR"
        )
        val conversations = MutableStateFlow(listOf(item("task-1", "RUNNING")))
        var cardState: Index9AssistantUiState? = null
        var rememberedSession: String? = null
        var syncCount = 0
        val controller = controller(
            uiState = MutableStateFlow(uiState),
            conversationList = conversations,
            events = events,
            agentSessionId = { " " },
            onCardUpdated = { _, state -> cardState = state },
            onRemember = { rememberedSession = it },
            onSync = { syncCount++ }
        )

        controller.pauseAndResetLocalUi(reason = "navigate_back_pause", reloadConversations = true)

        assertSame(uiState, cardState)
        assertEquals("task-1", rememberedSession)
        assertEquals(1, syncCount)
        assertEquals("EXECUTION_ERROR", conversations.value.single().status)
        assertOrdered(events, "card:task-1", "stop:navigate_back_pause", "remember:task-1", "reset", "load:vm_pause:navigate_back_pause")
    }

    @Test
    fun pauseAndResetUsesAgentSessionAndSkipsReloadWhenDisabled() {
        val events = mutableListOf<String>()
        val conversations = MutableStateFlow(listOf(item("agent-1", "RUNNING")))
        val controller = controller(
            uiState = MutableStateFlow(Index9AssistantUiState(taskId = "task-fallback", taskStatus = "RUNNING")),
            conversationList = conversations,
            events = events,
            agentSessionId = { " agent-1 " }
        )

        controller.pauseAndResetLocalUi(reason = "custom_pause", reloadConversations = false)

        assertEquals("RUNNING", conversations.value.single().status)
        assertTrue(events.contains("card:agent-1"))
        assertTrue(events.contains("stop:custom_pause"))
        assertTrue(events.contains("reset"))
        assertFalse(events.any { it.startsWith("remember:") })
        assertFalse(events.any { it.startsWith("sync") })
        assertFalse(events.any { it.startsWith("load:") })
        assertOrdered(events, "card:agent-1", "stop:custom_pause", "reset")
    }

    @Test
    fun lifecycleHandlerDelegatesExitResetWorkToController() {
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/AssistantTaskConversationLifecycleHandler.kt"
        ).readText(Charsets.UTF_8)
        val controller = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationExitResetController.kt"
        ).readText(Charsets.UTF_8)
        val pauseBody = handler
            .substringAfter("fun pauseAndResetLocalUi")
            .substringBefore("\n\n    @Suppress")

        assertTrue(handler.contains("TaskConversationExitResetController("))
        assertFalse(handler.contains("TaskConversationExitResetStateReader(deps.uiState)"))
        assertFalse(handler.contains("TaskConversationExitResetStateReader("))
        assertTrue(handler.contains("stateReader = deps.stateAccess.exitResetStateReader"))
        assertTrue(handler.contains("taskRestoreStateHolder = deps.stateAccess.taskRestoreStateHolder"))
        assertTrue(pauseBody.contains("exitResetController.pauseAndResetLocalUi(reason, reloadConversations)"))
        assertFalse(pauseBody.contains("shouldPersistExecutionErrorOnTaskExit("))
        assertFalse(pauseBody.contains("rememberPendingExecutionErrorExit(sessionId)"))
        assertFalse(pauseBody.contains("TaskConversationListStatusReducer.updateStatus("))
        assertFalse(pauseBody.contains("syncPendingExecutionErrorExitSessions()"))
        assertFalse(pauseBody.contains("loadConversations(reason = \"vm_pause:"))

        assertTrue(controller.contains("shouldPersistExecutionErrorOnTaskExit("))
        assertTrue(controller.contains("deps.stateReader.currentState()"))
        assertTrue(controller.contains("rememberPendingExecutionErrorExit(sessionId)"))
        assertTrue(controller.contains("deps.taskRestoreStateHolder.updateConversationCardStatus("))
        assertFalse(controller.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertFalse(controller.contains("deps.uiState.value"))
        assertFalse(controller.contains("TaskConversationListStatusReducer.updateStatus("))
        assertFalse(controller.contains("MutableStateFlow<List<ConversationListItem>>"))
        assertTrue(controller.contains("syncPendingExecutionErrorExitSessions()"))
        assertTrue(controller.contains("loadConversations(\"vm_pause:\$reason\")"))
    }

    private fun controller(
        uiState: MutableStateFlow<Index9AssistantUiState>,
        conversationList: MutableStateFlow<List<ConversationListItem>>,
        events: MutableList<String>,
        agentSessionId: () -> String?,
        onCardUpdated: (String?, Index9AssistantUiState) -> Unit = { _, _ -> },
        onRemember: (String) -> Unit = {},
        onSync: () -> Unit = {}
    ): TaskConversationExitResetController {
        return TaskConversationExitResetController(
            deps = TaskConversationExitResetDeps(
                scope = CoroutineScope(Dispatchers.Unconfined),
                stateReader = TaskConversationExitResetStateReader(uiState),
                taskRestoreStateHolder = TaskRestoreStateHolder(conversationList)
            ),
            callbacks = TaskConversationExitResetCallbacks(
                stopVoiceInteraction = { reason -> events += "stop:$reason" },
                resetToIdleHome = { events += "reset" },
                agentSessionId = agentSessionId,
                updateCurrentConversationCardBeforeExit = { sessionId, state ->
                    events += "card:$sessionId"
                    onCardUpdated(sessionId, state)
                },
                rememberPendingExecutionErrorExit = { sessionId ->
                    events += "remember:$sessionId"
                    onRemember(sessionId)
                },
                syncPendingExecutionErrorExitSessions = {
                    events += "sync"
                    onSync()
                    true
                }
            ),
            loadConversations = { reason -> events += "load:$reason" }
        )
    }

    private fun assertOrdered(events: List<String>, vararg expected: String) {
        val indices = expected.map { event ->
            events.indexOf(event).also { index ->
                assertTrue("Missing event $event in $events", index >= 0)
            }
        }
        assertEquals(indices.sorted(), indices)
    }

    private fun item(sessionId: String, status: String): ConversationListItem {
        return ConversationListItem(sessionId = sessionId, title = sessionId, status = status)
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
