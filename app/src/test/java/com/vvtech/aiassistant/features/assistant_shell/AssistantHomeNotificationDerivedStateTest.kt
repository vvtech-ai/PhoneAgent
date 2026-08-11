package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.features.assistant.FinalTaskStatusKind
import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.model.ConversationListItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeNotificationDerivedStateTest {
    @Test
    fun mergesVisibleCallRecordsAndDeduplicatesBackendHistory() {
        val derived = deriveAssistantHomeNotificationState(
            input(
                localCallRecords = listOf(
                    FinalCallRecord("给小明打电话", "成功", "刚刚", success = true)
                ),
                backendHistoryRecords = listOf(
                    HistoryRecord("给小明打电话", "成功", StatusStyle.Success, "刚刚"),
                    HistoryRecord("预订包间", "失败", StatusStyle.Failure, "昨天")
                )
            )
        )

        assertEquals(2, derived.visibleCallRecords.size)
        assertTrue(derived.visibleCallRecords.first { it.title == "给小明打电话" }.success)
        assertFalse(derived.visibleCallRecords.first { it.title == "预订包间" }.success)
    }

    @Test
    fun keepsCallRecordsWithDifferentCallIdsEvenWhenTitleStatusAndMetaMatch() {
        val derived = deriveAssistantHomeNotificationState(
            input(
                backendHistoryRecords = listOf(
                    HistoryRecord(
                        title = "[Mock] 老九 会议邀请",
                        status = "已确认参会",
                        style = StatusStyle.Success,
                        meta = "会议邀请完成",
                        phoneNumber = "13800138000",
                        taskId = "meeting-task",
                        callId = "batch:first:person-1",
                        resultText = "第一次确认三点参加"
                    ),
                    HistoryRecord(
                        title = "[Mock] 老九 会议邀请",
                        status = "已确认参会",
                        style = StatusStyle.Success,
                        meta = "会议邀请完成",
                        phoneNumber = "13800138000",
                        taskId = "meeting-task",
                        callId = "batch:second:person-1",
                        resultText = "第二次确认四点参加"
                    )
                )
            )
        )

        assertEquals(2, derived.visibleCallRecords.size)
        assertEquals(
            listOf("batch:first:person-1", "batch:second:person-1"),
            derived.visibleCallRecords.map { it.callId }
        )
    }

    @Test
    fun derivesPendingNotificationsBadgeAndCurrentDisplayFields() {
        val derived = deriveAssistantHomeNotificationState(
            input(
                taskRecords = listOf(
                    FinalTaskRecord(
                        title = "会议邀请",
                        status = "已完成",
                        detail = "今天",
                        notificationId = "task-1"
                    ),
                    FinalTaskRecord(
                        title = "包间预订",
                        status = "已完成",
                        detail = "明天",
                        notificationId = "task-2"
                    )
                ),
                conversations = listOf(
                    ConversationListItem("session-1", "已完成会话", "COMPLETED"),
                    ConversationListItem("session-2", "进行中会话", "RUNNING")
                )
            )
        )

        assertEquals(2, derived.visibleTaskRecords.size)
        assertEquals(1, derived.completedConversations.size)
        assertEquals(3, derived.taskBadgeCount)
        assertTrue(derived.homeNotificationVisible)
        assertTrue(derived.homeNotificationText.isNotBlank())
        assertEquals("还有 2 条", derived.homeNotificationExtra)
        assertEquals(FinalTaskStatusKind.Completed, derived.homeNotificationStatusKind)
    }

    @Test
    fun dismissedNotificationIdsFilterPendingItemsAndNonHomePageHidesBanner() {
        val derived = deriveAssistantHomeNotificationState(
            input(
                currentPage = FinalPage.Tasks,
                taskRecords = listOf(
                    FinalTaskRecord(
                        title = "会议邀请",
                        status = "已完成",
                        detail = "今天",
                        notificationId = "task-1"
                    ),
                    FinalTaskRecord(
                        title = "包间预订",
                        status = "已完成",
                        detail = "明天",
                        notificationId = "task-2"
                    )
                ),
                dismissedHomeNotificationIds = listOf("task-1")
            )
        )

        assertEquals(1, derived.pendingHomeNotifications.size)
        assertEquals(1, derived.taskBadgeCount)
        assertFalse(derived.homeNotificationVisible)
        assertEquals("", derived.homeNotificationExtra)
    }

    private fun input(
        currentPage: FinalPage = FinalPage.Home,
        localCallRecords: List<FinalCallRecord> = emptyList(),
        backendHistoryRecords: List<HistoryRecord> = emptyList(),
        taskRecords: List<FinalTaskRecord> = emptyList(),
        conversations: List<ConversationListItem> = emptyList(),
        dismissedHomeNotificationIds: List<String> = emptyList()
    ) = AssistantHomeNotificationDerivedStateInput(
        currentPage = currentPage,
        localCallRecords = localCallRecords,
        backendHistoryRecords = backendHistoryRecords,
        taskRecords = taskRecords,
        conversations = conversations,
        dismissedHomeNotificationIds = dismissedHomeNotificationIds
    )
}
