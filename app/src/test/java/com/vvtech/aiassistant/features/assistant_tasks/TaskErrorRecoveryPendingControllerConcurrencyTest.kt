package com.vvtech.aiassistant.features.assistant_tasks

import android.app.Application
import android.content.Context
import com.vvtech.aiassistant.core.model.AgentConversationInterruptResponse
import com.vvtech.aiassistant.model.ConversationListItem
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class TaskErrorRecoveryPendingControllerConcurrencyTest {

    @Test
    fun lateExecutionErrorExitCannotOverwriteTheRecoveredStableStatus() = runBlocking {
        val context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("index9_task_error_exit", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        val sessionId = "race-session"
        val conversations = MutableStateFlow(
            listOf(ConversationListItem(sessionId, "任务", "INCOMPLETE"))
        )
        val exitStarted = CompletableDeferred<Unit>()
        val releaseExit = CompletableDeferred<Unit>()
        val recoveryCalled = CompletableDeferred<Unit>()
        val requestOrder = mutableListOf<String>()
        val useCase = TaskErrorRecoveryPendingSyncUseCase(
            interruptConversation = { requestedSessionId, _, reason ->
                requestOrder += reason.orEmpty()
                when (reason) {
                    "execution_error_exit" -> {
                        exitStarted.complete(Unit)
                        releaseExit.await()
                        AgentConversationInterruptResponse(requestedSessionId, "EXECUTION_ERROR")
                    }
                    "execution_error_recovered" -> {
                        recoveryCalled.complete(Unit)
                        AgentConversationInterruptResponse(requestedSessionId, "INCOMPLETE")
                    }
                    else -> error("unexpected reason=$reason")
                }
            },
            log = {},
            accountId = { "account-a" },
            warn = {}
        )
        val pendingStore = TaskErrorRecoveryPendingStore(context)
        val controller = TaskErrorRecoveryPendingController(
            pendingStore = pendingStore,
            pendingStatusHolder = TaskErrorRecoveryPendingStatusHolder(conversations),
            pendingSyncUseCase = useCase
        )

        controller.rememberPendingExecutionErrorExit(sessionId)
        val exitSync = async { controller.syncPendingExecutionErrorExitSessions() }
        exitStarted.await()
        controller.rememberPendingExecutionErrorRecovered(sessionId)
        val recoverySync = async { controller.syncPendingExecutionErrorRecoveredSessions() }

        assertNull(withTimeoutOrNull(100) { recoveryCalled.await() })
        releaseExit.complete(Unit)
        assertTrue(exitSync.await())
        assertTrue(recoverySync.await())

        assertEquals(
            listOf("execution_error_exit", "execution_error_recovered"),
            requestOrder
        )
        assertEquals("INCOMPLETE", conversations.value.single().status)
        assertFalse(pendingStore.pendingExecutionErrorExitSessions().contains(sessionId))
        assertFalse(pendingStore.pendingExecutionErrorRecoveredSessions().contains(sessionId))
    }
}
