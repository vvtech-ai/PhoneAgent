package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant.FinalHomeNotificationItem
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeNotificationReadStateTest {
    @Test
    fun markReadMergesFiltersAndPersistsDistinctIds() {
        val persisted = mutableListOf<Set<String>>()
        val state = AssistantHomeNotificationReadState(
            dismissedIdsState = mutableStateOf(listOf("old")),
            persistDismissedIds = { persisted += it }
        )

        val changed = state.markRead(listOf("new", "", "old", "new-2"))

        assertTrue(changed)
        assertEquals(listOf("old", "new", "new-2"), state.dismissedIds)
        assertEquals(setOf("old", "new", "new-2"), persisted.single())
    }

    @Test
    fun markReadSkipsPersistenceWhenNothingChanges() {
        val persisted = mutableListOf<Set<String>>()
        val state = AssistantHomeNotificationReadState(
            dismissedIdsState = mutableStateOf(listOf("old")),
            persistDismissedIds = { persisted += it }
        )

        val changed = state.markRead(listOf("old", ""))

        assertFalse(changed)
        assertEquals(listOf("old"), state.dismissedIds)
        assertTrue(persisted.isEmpty())
    }

    @Test
    fun readActionsMarkPendingNotificationsAndDismissCurrent() {
        val persisted = mutableListOf<Set<String>>()
        val state = AssistantHomeNotificationReadState(
            dismissedIdsState = mutableStateOf(listOf("old")),
            persistDismissedIds = { persisted += it }
        )
        val pending = listOf(
            FinalHomeNotificationItem(id = "task-1", text = "任务一"),
            FinalHomeNotificationItem(id = "task-2", text = "任务二")
        )

        val pendingChanged = AssistantHomeNotificationReadActions.markPendingRead(state, pending)
        val emptyDismissChanged = AssistantHomeNotificationReadActions.dismissCurrent(state, null)
        val currentDismissChanged = AssistantHomeNotificationReadActions.dismissCurrent(
            state,
            FinalHomeNotificationItem(id = "task-3", text = "任务三")
        )

        assertTrue(pendingChanged)
        assertFalse(emptyDismissChanged)
        assertTrue(currentDismissChanged)
        assertEquals(listOf("old", "task-1", "task-2", "task-3"), state.dismissedIds)
        assertEquals(setOf("old", "task-1", "task-2", "task-3"), persisted.last())
    }

    @Test
    fun userCloseDismissesNotificationsThatArriveAfterTaskUiWasClosed() {
        val state = AssistantHomeNotificationReadState(mutableStateOf(emptyList()))

        val changed = AssistantHomeNotificationReadActions.dismissTaskForUserClose(
            readState = state,
            sessionId = "session-1",
            taskId = "task-1"
        )
        val derived = deriveAssistantHomeNotificationState(
            AssistantHomeNotificationDerivedStateInput(
                currentPage = FinalPage.Home,
                localCallRecords = emptyList(),
                backendHistoryRecords = emptyList(),
                taskRecords = listOf(
                    FinalTaskRecord("新任务", "失败", "稍后到达", notificationId = "assistant_task_task-1"),
                    FinalTaskRecord("旧任务", "失败", "稍后到达", notificationId = "legacy_task_task-1")
                ),
                conversations = listOf(ConversationListItem("session-1", "通话结果", "COMPLETED")),
                dismissedHomeNotificationIds = state.dismissedIds
            )
        )

        assertTrue(changed)
        assertEquals(
            listOf("conversation_session-1", "assistant_task_task-1", "legacy_task_task-1"),
            state.dismissedIds
        )
        assertTrue(derived.pendingHomeNotifications.isEmpty())
        assertFalse(derived.homeNotificationVisible)
    }

    @Test
    fun assistantRootScreenDelegatesHomeNotificationReadState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantHomeNotificationReadState.kt")
                .readText(Charsets.UTF_8)
        val actions =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantHomeNotificationReadActions.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)
        val runtime =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantHomeNotificationRuntimeShell.kt")
                .readText(Charsets.UTF_8)
        val assistantFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText(Charsets.UTF_8)
        val rootNavigationActions =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootNavigationActions.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val homeNotificationReadState = rootRuntimeGraph.state.homeNotificationRead"))
        assertTrue(runtimeGraph.contains("rememberAssistantHomeNotificationReadState(prefs)"))
        assertFalse(root.contains("homeNotificationReadState.dismissedIds"))
        assertTrue(root.contains("homeNotificationRead = homeNotificationReadState"))
        assertFalse(root.contains("AssistantHomeNotificationReadActions.markPendingRead("))
        assertFalse(root.contains("AssistantHomeNotificationReadActions.dismissCurrent("))
        assertFalse(root.contains("fun markHomeNotificationsRead("))
        assertFalse(root.contains("fun markPendingHomeNotificationsRead("))
        assertFalse(root.contains("homeNotificationReadState.markRead(notificationIds)"))
        assertFalse(root.contains("var dismissedHomeNotificationIds by rememberSaveable"))
        assertFalse(root.contains("putStringSet(FinalReadHomeNotificationIdsKey"))

        assertTrue(holder.contains("FinalReadHomeNotificationIdsKey"))
        assertTrue(holder.contains("fun markRead(notificationIds: Iterable<String>): Boolean"))
        assertTrue(holder.contains("putStringSet(FinalReadHomeNotificationIdsKey, ids)"))
        assertTrue(actions.contains("fun markPendingRead("))
        assertTrue(actions.contains("fun dismissCurrent("))
        assertTrue(actions.contains("fun dismissTaskForUserClose("))
        assertTrue(actionGraph.contains("AssistantHomeNotificationReadActions.dismissTaskForUserClose("))
        assertTrue(runtime.contains("input.readState.dismissedIds"))
        assertTrue(runtime.contains("AssistantHomeNotificationReadActions.markPendingRead("))
        assertTrue(assistantFactory.contains("AssistantHomeNotificationReadActions.dismissCurrent("))
        assertTrue(assistantFactory.contains("readState = state.homeNotificationRead"))
        assertTrue(rootNavigationActions.contains("AssistantHomeNotificationReadActions.markPendingRead("))
        assertTrue(rootNavigationActions.contains("readState = deps.taskTab.readState"))
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
