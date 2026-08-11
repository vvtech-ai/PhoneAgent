package com.vvtech.aiassistant.features.assistant_tasks

import com.google.gson.Gson
import com.vvtech.aiassistant.features.assistant.toCompletedTaskRecord
import com.vvtech.aiassistant.features.assistant.toFinalTaskDisplayItem
import com.vvtech.aiassistant.model.ConversationListItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskPageRowsNullTitleTest {

    @Test
    fun nullApiTitleFallsBackForActiveAndCompletedConversationRows() {
        val activeConversation = conversationWithNullTitle("active-session", "RUNNING")
        val completedConversation = conversationWithNullTitle("completed-session", "COMPLETED")

        val result = buildTaskPageRows(
            records = emptyList(),
            conversations = listOf(activeConversation, completedConversation)
        )

        assertEquals(
            setOf("active-session", "completed-session"),
            result.rows.mapNotNull { it.conversationSessionId }.toSet()
        )
        assertTrue(result.rows.all { it.item.displayTitle.isNotBlank() })
    }

    @Test
    fun activatedSkillOnlyOverridesTaskTitlePrefix() {
        val conversation = ConversationListItem(
            sessionId = "meeting-session",
            title = "老王、老邱",
            status = "COMPLETED",
            sceneType = "AI_CALL",
            activeSkillId = "meeting_notification"
        )

        val baseline = conversation.toCompletedTaskRecord().toFinalTaskDisplayItem()
        val item = buildTaskPageRows(emptyList(), listOf(conversation)).rows.single().item

        assertEquals("会议邀请 · 老王、老邱", item.displayTitle)
        assertEquals(baseline.secondaryLine, item.secondaryLine)
        assertEquals(baseline.statusLabel, item.statusLabel)
    }

    private fun conversationWithNullTitle(sessionId: String, status: String): ConversationListItem {
        return Gson().fromJson(
            """
            {
              "sessionId": "$sessionId",
              "title": null,
              "status": "$status",
              "sceneType": "RESTAURANT_BOOKING"
            }
            """.trimIndent(),
            ConversationListItem::class.java
        )
    }
}
