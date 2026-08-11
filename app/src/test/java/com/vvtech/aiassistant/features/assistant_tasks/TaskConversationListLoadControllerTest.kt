package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskConversationListLoadControllerTest {
    @Test
    fun loadSyncsPendingAndAppliesLatestPendingStatuses() {
        val events = mutableListOf<String>()
        val conversationList = MutableStateFlow<List<ConversationListItem>>(emptyList())
        val conversationLoading = MutableStateFlow(false)
        val conversationError = MutableStateFlow<String?>("old")
        val controller = controller(
            conversationList = conversationList,
            conversationLoading = conversationLoading,
            conversationError = conversationError,
            events = events,
            pendingExit = { setOf("exit-1") },
            pendingRecovered = { setOf("recovered-1") },
            load = { accountId, pendingExit, pendingRecovered ->
                events += "load:$accountId:${pendingExit.joinToString()}:${pendingRecovered.joinToString()}"
                listOf(item("exit-1", "RUNNING"), item("recovered-1", "EXECUTION_ERROR"))
            }
        )

        controller.loadConversations("settings")

        assertEquals(listOf("syncExit", "syncRecovered", "load:account-1:exit-1:recovered-1"), events)
        assertEquals(listOf("EXECUTION_ERROR", "EXECUTION_ERROR"), conversationList.value.map { it.status })
        assertFalse(conversationLoading.value)
        assertNull(conversationError.value)
    }

    @Test
    fun loadSkipsWhenAlreadyLoading() {
        val events = mutableListOf<String>()
        val conversationLoading = MutableStateFlow(true)
        val controller = controller(
            conversationLoading = conversationLoading,
            events = events,
            load = { _, _, _ -> error("should not load") }
        )

        controller.loadConversations()

        assertTrue(events.isEmpty())
        assertTrue(conversationLoading.value)
    }

    @Test
    fun loadFailureWritesErrorAndReleasesLoading() {
        val events = mutableListOf<String>()
        val warnings = mutableListOf<String>()
        val conversationError = MutableStateFlow<String?>(null)
        val conversationLoading = MutableStateFlow(false)
        val controller = controller(
            conversationLoading = conversationLoading,
            conversationError = conversationError,
            events = events,
            warnings = warnings,
            load = { _, _, _ -> error("backend unavailable") }
        )

        controller.loadConversations()

        assertEquals(listOf("syncExit", "syncRecovered"), events)
        assertEquals("backend unavailable", conversationError.value)
        assertEquals("loadConversations failed: backend unavailable", warnings.single())
        assertFalse(conversationLoading.value)
    }

    @Test
    fun lifecycleHandlerDelegatesListLoadWorkToController() {
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/AssistantTaskConversationLifecycleHandler.kt"
        ).readText(Charsets.UTF_8)
        val controller = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationListLoadController.kt"
        ).readText(Charsets.UTF_8)
        val stateHolder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationListLoadStateHolder.kt"
        ).readText(Charsets.UTF_8)
        val loadBody = handler
            .substringAfter("fun loadConversations")
            .substringBefore("\n\n    fun returnToHomeFromResultPage")

        assertTrue(handler.contains("TaskConversationListLoadController("))
        assertFalse(handler.contains("TaskConversationListLoadStateHolder("))
        assertTrue(handler.contains("stateHolder = deps.stateAccess.listLoadStateHolder"))
        assertTrue(loadBody.contains("listLoadController.loadConversations(reason)"))
        assertFalse(loadBody.contains("conversationLoading.value"))
        assertFalse(loadBody.contains("conversationListLoadUseCase.load("))
        assertFalse(loadBody.contains("withPendingExecutionErrorExitStatuses("))
        assertFalse(loadBody.contains("loadConversations failed:"))

        assertTrue(controller.contains("val stateHolder: TaskConversationListLoadStateHolder"))
        assertTrue(controller.contains("private val stateHolder = deps.stateHolder"))
        assertTrue(controller.contains("stateHolder.beginLoad()"))
        assertTrue(controller.contains("stateHolder.applyLoadedConversations("))
        assertTrue(controller.contains("stateHolder.applyLoadFailure(throwable.message)"))
        assertTrue(controller.contains("stateHolder.finishLoad()"))
        assertTrue(controller.contains("callbacks.syncPendingExecutionErrorExitSessions()"))
        assertTrue(controller.contains("deps.load("))
        assertTrue(controller.contains("loadConversations failed:"))
        assertFalse(controller.contains("TaskConversationListLoadStateHolder("))
        assertFalse(controller.contains("MutableStateFlow<"))
        assertFalse(controller.contains("conversationList: MutableStateFlow"))
        assertFalse(controller.contains("conversationLoading: MutableStateFlow"))
        assertFalse(controller.contains("conversationError: MutableStateFlow"))
        assertFalse(controller.contains("deps.conversationList.value ="))
        assertFalse(controller.contains("deps.conversationLoading.value ="))
        assertFalse(controller.contains("deps.conversationError.value ="))
        assertFalse(controller.contains("withPendingExecutionErrorExitStatuses("))
        assertFalse(controller.contains("withRecoveredExecutionErrorStatuses("))

        assertTrue(stateHolder.contains("conversationLoading.value = true"))
        assertTrue(stateHolder.contains("conversationList.value = conversations"))
        assertTrue(stateHolder.contains("withPendingExecutionErrorExitStatuses(pendingExecutionErrorExitSessions)"))
        assertFalse(stateHolder.contains("withRecoveredExecutionErrorStatuses(pendingExecutionErrorRecoveredSessions)"))
        assertTrue(stateHolder.contains("conversationError.value = message ?: \"Conversation list load failed\""))
        assertTrue(stateHolder.contains("conversationLoading.value = false"))
    }

    private fun controller(
        conversationList: MutableStateFlow<List<ConversationListItem>> = MutableStateFlow(emptyList()),
        conversationLoading: MutableStateFlow<Boolean> = MutableStateFlow(false),
        conversationError: MutableStateFlow<String?> = MutableStateFlow(null),
        events: MutableList<String>,
        warnings: MutableList<String> = mutableListOf(),
        pendingExit: () -> Set<String> = { emptySet() },
        pendingRecovered: () -> Set<String> = { emptySet() },
        load: suspend (String, Set<String>, Set<String>) -> List<ConversationListItem>
    ): TaskConversationListLoadController {
        return TaskConversationListLoadController(
            deps = TaskConversationListLoadControllerDeps(
                scope = CoroutineScope(Dispatchers.Unconfined),
                stateHolder = TaskConversationListLoadStateHolder(
                    conversationList = conversationList,
                    conversationLoading = conversationLoading,
                    conversationError = conversationError
                ),
                accountIdProvider = { "account-1" },
                load = load
            ),
            callbacks = TaskConversationListLoadControllerCallbacks(
                pendingExecutionErrorExitSessions = pendingExit,
                pendingExecutionErrorRecoveredSessions = pendingRecovered,
                syncPendingExecutionErrorExitSessions = {
                    events += "syncExit"
                    true
                },
                syncPendingExecutionErrorRecoveredSessions = {
                    events += "syncRecovered"
                    true
                }
            ),
            warn = { warning -> warnings += warning }
        )
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
