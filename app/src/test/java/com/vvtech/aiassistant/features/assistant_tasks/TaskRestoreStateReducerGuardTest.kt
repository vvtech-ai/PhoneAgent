package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskRestoreStateReducerGuardTest {
    @Test
    fun reducerUpdatesOnlyMatchingConversationCard() {
        val conversations = listOf(
            ConversationListItem(sessionId = "session-1", title = "one", status = "RUNNING"),
            ConversationListItem(sessionId = "session-2", title = "two", status = "COMPLETED")
        )

        val updated = TaskRestoreStateReducer.updateConversationCardStatus(
            conversations = conversations,
            sessionId = "session-1",
            status = "EXECUTION_ERROR"
        )

        assertEquals("EXECUTION_ERROR", updated[0].status)
        assertEquals("COMPLETED", updated[1].status)
    }

    @Test
    fun holderUpdatesConversationCardThroughTaskReducer() {
        val conversationList = MutableStateFlow(
            listOf(
                ConversationListItem(sessionId = "session-1", title = "one", status = "RUNNING"),
                ConversationListItem(sessionId = "session-2", title = "two", status = "COMPLETED")
            )
        )
        val holder = TaskRestoreStateHolder(conversationList)

        holder.updateConversationCardStatus("session-2", "NETWORK_ERROR")

        assertEquals("RUNNING", conversationList.value[0].status)
        assertEquals("NETWORK_ERROR", conversationList.value[1].status)
    }

    @Test
    fun reducerAndHolderDoNotLiveInViewModelPackage() {
        val oldReducer = File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/TaskRestoreStateReducer.kt")
        val oldHolder = File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/TaskRestoreStateHolder.kt")
        val holder = File("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskRestoreStateHolder.kt")
            .readText()
        val reducer = File("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskRestoreStateReducer.kt")
            .readText()

        assertFalse(oldReducer.exists())
        assertFalse(oldHolder.exists())
        assertTrue(holder.contains("package com.vvtech.aiassistant.features.assistant_tasks"))
        assertTrue(holder.contains("TaskRestoreStateReducer.updateConversationCardStatus"))
        assertFalse(holder.contains("features.assistant.viewmodel"))
        assertTrue(reducer.contains("object TaskRestoreStateReducer"))
        assertTrue(reducer.contains("TaskConversationListStatusReducer.updateStatus"))
    }
}
