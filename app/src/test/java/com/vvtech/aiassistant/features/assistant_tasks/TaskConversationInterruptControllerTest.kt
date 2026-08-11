package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskConversationInterruptControllerTest {
    @Test
    fun interruptSuccessUpdatesConversationAndReloads() {
        val events = mutableListOf<String>()
        val conversations = MutableStateFlow(listOf(item("session-1", "RUNNING")))
        val controller = controller(
            conversationList = conversations,
            events = events,
            agentSessionId = { "session-1" },
            interrupt = { sessionId, accountId, reason ->
                events += "interrupt:$sessionId:$accountId:$reason"
                TaskConversationInterruptResult(status = "USER_INTERRUPTED", fallbackStatus = "fallback")
            }
        )

        controller.interruptForUserClose("user_close")

        assertEquals("USER_INTERRUPTED", conversations.value.single().status)
        assertTrue(events.contains("stop:user_close"))
        assertTrue(events.contains("interrupt:session-1:account-1:user_close"))
        assertTrue(events.contains("load"))
        assertTrue(events.contains("reset"))
    }

    @Test
    fun interruptFailureAppliesFallbackAndWarns() {
        val events = mutableListOf<String>()
        val conversations = MutableStateFlow(listOf(item("session-1", "RUNNING")))
        val warnings = mutableListOf<String>()
        val controller = controller(
            conversationList = conversations,
            events = events,
            warnings = warnings,
            agentSessionId = { "session-1" },
            fallbackStatus = { "RUNNING" },
            interrupt = { _, _, _ -> error("network down") }
        )

        controller.interruptForUserClose("reset_task_flow")

        assertEquals("RUNNING", conversations.value.single().status)
        assertTrue(events.contains("stop:reset_task_flow"))
        assertTrue(events.contains("reset"))
        assertFalse(events.contains("load"))
        assertEquals("interrupt conversation failed session=session-1: network down", warnings.single())
    }

    @Test
    fun emptySessionOnlyStopsAndResets() {
        val events = mutableListOf<String>()
        val conversations = MutableStateFlow(listOf(item("session-1", "RUNNING")))
        val controller = controller(
            conversationList = conversations,
            events = events,
            agentSessionId = { " " },
            interrupt = { _, _, _ -> error("should not run") }
        )

        controller.interruptForUserClose("user_close")

        assertEquals("RUNNING", conversations.value.single().status)
        assertEquals(listOf("stop:user_close", "reset"), events)
    }

    @Test
    fun lifecycleHandlerDelegatesInterruptWorkToController() {
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/AssistantTaskConversationLifecycleHandler.kt"
        ).readText(Charsets.UTF_8)
        val controller = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationInterruptController.kt"
        ).readText(Charsets.UTF_8)
        val interruptBody = handler
            .substringAfter("fun interruptForUserClose")
            .substringBefore("\n\n    fun pauseForBackground")

        assertTrue(handler.contains("TaskConversationInterruptController("))
        assertTrue(interruptBody.contains("interruptController.interruptForUserClose(reason)"))
        assertFalse(interruptBody.contains("conversationInterruptUseCase.interrupt("))
        assertFalse(interruptBody.contains("conversationInterruptUseCase.fallbackStatus("))
        assertFalse(interruptBody.contains("TaskConversationListStatusReducer.updateStatus("))
        assertFalse(interruptBody.contains("interrupt conversation failed session="))
        assertFalse(interruptBody.contains("loadConversations()"))

        assertTrue(controller.contains("deps.interrupt("))
        assertTrue(controller.contains("deps.fallbackStatus(reason)"))
        assertTrue(controller.contains("deps.taskRestoreStateHolder.updateConversationCardStatus("))
        assertFalse(controller.contains("TaskConversationListStatusReducer.updateStatus("))
        assertFalse(controller.contains("MutableStateFlow<List<ConversationListItem>>"))
        assertTrue(controller.contains("interrupt conversation failed session=\$sessionId"))
        assertTrue(controller.contains("loadConversations()"))
    }

    private fun controller(
        conversationList: MutableStateFlow<List<ConversationListItem>>,
        events: MutableList<String>,
        warnings: MutableList<String> = mutableListOf(),
        agentSessionId: () -> String?,
        fallbackStatus: (String) -> String = { "USER_INTERRUPTED" },
        interrupt: suspend (String, String, String) -> TaskConversationInterruptResult
    ): TaskConversationInterruptController {
        return TaskConversationInterruptController(
            deps = TaskConversationInterruptControllerDeps(
                scope = CoroutineScope(Dispatchers.Unconfined),
                taskRestoreStateHolder = TaskRestoreStateHolder(conversationList),
                accountIdProvider = { "account-1" },
                fallbackStatus = fallbackStatus,
                interrupt = interrupt
            ),
            callbacks = TaskConversationInterruptControllerCallbacks(
                stopVoiceInteraction = { reason -> events += "stop:$reason" },
                resetToIdleHome = { events += "reset" },
                agentSessionId = agentSessionId
            ),
            loadConversations = { events += "load" },
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
