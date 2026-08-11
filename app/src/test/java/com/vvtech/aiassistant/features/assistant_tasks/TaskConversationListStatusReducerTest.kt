package com.vvtech.aiassistant.features.assistant_tasks

import com.google.gson.Gson
import com.vvtech.aiassistant.model.ConversationListItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskConversationListStatusReducerTest {
    @Test
    fun updateStatusOnlyChangesMatchingSessionAndKeepsOrder() {
        val conversations = listOf(
            item("session-1", "RUNNING"),
            item("session-2", "COMPLETED"),
            item("session-3", "PENDING")
        )

        val updated = TaskConversationListStatusReducer.updateStatus(
            conversations = conversations,
            sessionId = "session-2",
            status = "EXECUTION_ERROR"
        )

        assertEquals(listOf("session-1", "session-2", "session-3"), updated.map { it.sessionId })
        assertEquals(listOf("RUNNING", "EXECUTION_ERROR", "PENDING"), updated.map { it.status })
    }

    @Test
    fun updateStatusNormalizesRuntimeNullTitleFromConversationList() {
        val runtimeNullTitle = Gson().fromJson(
            """{"sessionId":"session-null-title","title":null,"status":"RUNNING"}""",
            ConversationListItem::class.java
        )

        val updated = TaskConversationListStatusReducer.updateStatus(
            conversations = listOf(runtimeNullTitle),
            sessionId = "session-null-title",
            status = "COMPLETED"
        )

        assertEquals("", updated.single().title)
        assertEquals("COMPLETED", updated.single().status)
    }

    @Test
    fun handlersDelegateConversationListStatusReducer() {
        val lifecycleHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/AssistantTaskConversationLifecycleHandler.kt")
                .readText(Charsets.UTF_8)
        val interruptController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationInterruptController.kt")
                .readText(Charsets.UTF_8)
        val exitResetController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationExitResetController.kt")
                .readText(Charsets.UTF_8)
        val listLoadUseCase =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationListLoadUseCase.kt")
                .readText(Charsets.UTF_8)
        val listLoadController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationListLoadController.kt")
                .readText(Charsets.UTF_8)
        val errorRecoveryHolder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryHolder.kt")
                .readText(Charsets.UTF_8)
        val errorRecoveryPendingSyncUseCase =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryPendingSyncUseCase.kt")
                .readText(Charsets.UTF_8)
        val oldRestoreHandler =
            sourceFileOrNull("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/ConversationRestoreHandler.kt")
        val restoreHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/ConversationRestoreHandler.kt")
                .readText(Charsets.UTF_8)
        val restoreStateHolder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskRestoreStateHolder.kt")
                .readText(Charsets.UTF_8)
        val reducer =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskConversationListStatusReducer.kt")
                .readText(Charsets.UTF_8)

        assertFalse(lifecycleHandler.contains("TaskConversationListStatusReducer.updateStatus"))
        assertTrue(interruptController.contains("taskRestoreStateHolder.updateConversationCardStatus"))
        assertTrue(exitResetController.contains("taskRestoreStateHolder.updateConversationCardStatus"))
        assertFalse(interruptController.contains("TaskConversationListStatusReducer.updateStatus"))
        assertFalse(exitResetController.contains("TaskConversationListStatusReducer.updateStatus"))
        assertFalse(lifecycleHandler.contains("TaskConversationListStatusReducer.resolveStatuses"))
        assertFalse(lifecycleHandler.contains("repository.getConversations("))
        assertFalse(lifecycleHandler.contains("repository.getConversation("))
        assertFalse(listLoadUseCase.contains("TaskConversationListStatusReducer.resolveStatuses"))
        assertTrue(listLoadUseCase.contains("repository.getConversations(accountId)"))
        assertFalse(listLoadUseCase.contains("repository.getConversation("))
        assertFalse(listLoadUseCase.contains("messagesJson"))
        assertTrue(lifecycleHandler.contains("accountIdProvider = deps.accountIdProvider"))
        assertTrue(listLoadController.contains("deps.accountIdProvider()"))
        assertFalse(lifecycleHandler.contains("AccountIdentityProvider"))
        assertFalse(lifecycleHandler.contains("DefaultUserId"))
        assertTrue(errorRecoveryPendingSyncUseCase.contains("TaskConversationListStatusReducer.updateStatus"))
        assertFalse(oldRestoreHandler?.exists() == true)
        assertTrue(restoreHandler.contains("package com.vvtech.aiassistant.features.assistant_session"))
        assertTrue(restoreHandler.contains("taskRestoreStateHolder.updateConversationCardStatus"))
        assertTrue(restoreStateHolder.contains("TaskRestoreStateReducer.updateConversationCardStatus"))
        assertFalse(reducer.contains("resolveStatuses"))
        assertFalse(reducer.contains("ConversationDetail"))

        assertFalse(lifecycleHandler.contains("withResolvedStatus(detail)"))
        assertFalse(lifecycleHandler.contains("shouldResolveConversationStatusFromDetail(item.status)"))
        assertFalse(lifecycleHandler.contains("item.copy(status = response.status)"))
        assertFalse(errorRecoveryHolder.contains("item.copy(status = response.status)"))
        assertFalse(errorRecoveryHolder.contains("TaskConversationListStatusReducer.updateStatus"))
        assertFalse(restoreHandler.contains("TaskConversationListStatusReducer.updateStatus"))
        assertFalse(restoreHandler.contains("conversationList.value = TaskConversationListStatusReducer.updateStatus"))
        assertFalse(restoreHandler.contains("item.copy(status = snapshot.resolvedStatus)"))
    }

    private companion object {
        fun item(sessionId: String, status: String): ConversationListItem {
            return ConversationListItem(
                sessionId = sessionId,
                title = sessionId,
                status = status
            )
        }
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }

        fun sourceFileOrNull(path: String): File? {
            return listOf(
                File(path),
                File("android/app/$path")
            ).firstOrNull { it.exists() }
        }
    }
}
