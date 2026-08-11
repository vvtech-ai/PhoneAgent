package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskErrorRecoveryPendingSyncUseCaseTest {
    @Test
    fun pendingSyncRepositorySideEffectsStayInUseCase() {
        val holder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryHolder.kt"
        ).readText(Charsets.UTF_8)
        val useCase = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryPendingSyncUseCase.kt"
        ).readText(Charsets.UTF_8)
        val pendingController = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryPendingController.kt"
        ).readText(Charsets.UTF_8)
        val pendingStatusHolder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryPendingStatusHolder.kt"
        ).readText(Charsets.UTF_8)
        val pendingStore = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryPendingStore.kt"
        ).readText(Charsets.UTF_8)
        val networkRetryController = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryNetworkRetryController.kt"
        ).readText(Charsets.UTF_8)
        val networkRegistrar = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskErrorRecoveryNetworkCallbackRegistrar.kt"
        ).readText(Charsets.UTF_8)

        val pendingControllerBody = pendingController.substringBefore(
            "internal object TaskErrorRecoveryPendingControllerFactory"
        )
        val pendingControllerFactory = pendingController.substringAfter(
            "internal object TaskErrorRecoveryPendingControllerFactory"
        )

        assertTrue(holder.contains("TaskErrorRecoveryPendingControllerFactory.create("))
        assertTrue(holder.contains("TaskErrorRecoveryNetworkRetryController("))
        assertTrue(holder.contains("pendingController.pendingExecutionErrorExitSessions()"))
        assertTrue(holder.contains("pendingController.rememberPendingExecutionErrorExit(sessionId)"))
        assertTrue(holder.contains("pendingController.pendingExecutionErrorRecoveredSessions()"))
        assertTrue(holder.contains("pendingController.syncPendingExecutionErrorExitSessions()"))
        assertTrue(holder.contains("pendingController.syncPendingExecutionErrorRecoveredSessions()"))
        assertTrue(holder.contains("pendingController::rememberPendingExecutionErrorRecovered"))
        assertTrue(holder.contains("networkRetryController.register()"))
        assertTrue(holder.contains("networkRetryController.unregister()"))
        assertTrue(holder.contains("TaskErrorRecoveryNetworkCallbackRegistrar(appContext)"))
        assertFalse(holder.contains("TaskErrorRecoveryPendingSyncUseCase("))
        assertFalse(holder.contains("TaskErrorRecoveryPendingStore(appContext)"))
        assertFalse(holder.contains("onSynced = pendingStore::forgetPendingExecutionErrorExit"))
        assertFalse(holder.contains("onSynced = pendingStore::forgetPendingExecutionErrorRecovered"))
        assertFalse(holder.contains("withPendingExecutionErrorExitStatuses(pending)"))
        assertFalse(holder.contains("withRecoveredExecutionErrorStatuses(pending)"))
        assertFalse(holder.contains("conversationList.value = result.conversations"))
        assertFalse(holder.contains("repository.interruptConversation("))
        assertFalse(holder.contains("AccountIdentityProvider.accountId"))
        assertFalse(holder.contains("ExecutionErrorExitReason"))
        assertFalse(holder.contains("ExecutionErrorRecoveredReason"))
        assertFalse(holder.contains("PendingExecutionErrorExitSessionsKey"))
        assertFalse(holder.contains("PendingExecutionErrorRecoveredSessionsKey"))
        assertFalse(holder.contains("getStringSet("))
        assertFalse(holder.contains("putStringSet("))
        assertFalse(holder.contains("ConnectivityManager.NetworkCallback"))
        assertFalse(holder.contains("registerDefaultNetworkCallback("))
        assertFalse(holder.contains("unregisterNetworkCallback("))

        assertTrue(pendingControllerBody.contains("private val pendingStore: TaskErrorRecoveryPendingStore"))
        assertTrue(pendingControllerBody.contains("private val pendingStatusHolder: TaskErrorRecoveryPendingStatusHolder"))
        assertTrue(pendingControllerBody.contains("private val pendingSyncUseCase: TaskErrorRecoveryPendingSyncUseCase"))
        assertTrue(pendingControllerBody.contains("private val syncMutex = Mutex()"))
        assertTrue(pendingControllerBody.countLiteral("syncMutex.withLock") == 2)
        assertTrue(pendingControllerBody.contains("pendingStore.pendingExecutionErrorExitSessions()"))
        assertTrue(pendingControllerBody.contains("pendingStore.rememberPendingExecutionErrorExit(sessionId)"))
        assertTrue(pendingControllerBody.contains("pendingStatusHolder.applyPendingExecutionErrorExitStatuses("))
        assertTrue(pendingControllerBody.contains("pendingStore.pendingExecutionErrorRecoveredSessions()"))
        assertTrue(pendingControllerBody.contains("pendingStore.rememberPendingExecutionErrorRecovered(sessionId)"))
        assertFalse(pendingControllerBody.contains("pendingStatusHolder.applyRecoveredExecutionErrorStatuses("))
        assertTrue(pendingControllerBody.contains("onSynced = pendingStore::forgetPendingExecutionErrorExit"))
        assertTrue(pendingControllerBody.contains("onSynced = pendingStore::forgetPendingExecutionErrorRecovered"))
        assertTrue(pendingControllerBody.contains("pendingStatusHolder.currentConversations()"))
        assertTrue(pendingControllerBody.contains("pendingStatusHolder.applySyncedConversations(result)"))
        assertFalse(pendingControllerBody.contains("appContext: Context"))
        assertFalse(pendingControllerBody.contains("repository: AssistantRepository"))
        assertFalse(pendingControllerBody.contains("conversationList: MutableStateFlow"))
        assertFalse(pendingControllerBody.contains("TaskErrorRecoveryPendingStore(appContext)"))
        assertFalse(pendingControllerBody.contains("TaskErrorRecoveryPendingStatusHolder(conversationList)"))
        assertFalse(pendingControllerBody.contains("TaskErrorRecoveryPendingSyncUseCase("))
        assertFalse(pendingControllerBody.contains("conversationList.value ="))
        assertFalse(pendingControllerBody.contains("withPendingExecutionErrorExitStatuses("))
        assertFalse(pendingControllerBody.contains("withRecoveredExecutionErrorStatuses("))
        assertFalse(pendingControllerBody.contains("result.conversations"))
        assertFalse(pendingControllerBody.contains("repository.interruptConversation("))
        assertFalse(pendingControllerBody.contains("AccountIdentityProvider.accountId"))

        assertTrue(pendingControllerFactory.contains("fun create("))
        assertTrue(pendingControllerFactory.contains("appContext: Context"))
        assertTrue(pendingControllerFactory.contains("repository: AssistantRepository"))
        assertTrue(pendingControllerFactory.contains("conversationList: MutableStateFlow"))
        assertTrue(pendingControllerFactory.contains("TaskErrorRecoveryPendingStore(appContext)"))
        assertTrue(pendingControllerFactory.contains("TaskErrorRecoveryPendingStatusHolder(conversationList)"))
        assertTrue(pendingControllerFactory.contains("TaskErrorRecoveryPendingSyncUseCase("))
        assertTrue(pendingControllerFactory.contains("repository = repository"))
        assertTrue(pendingControllerFactory.contains("log = log"))

        assertTrue(pendingStatusHolder.contains("internal class TaskErrorRecoveryPendingStatusHolder"))
        assertTrue(pendingStatusHolder.contains("fun currentConversations()"))
        assertTrue(pendingStatusHolder.contains("withPendingExecutionErrorExitStatuses(pendingSessions)"))
        assertFalse(pendingStatusHolder.contains("withRecoveredExecutionErrorStatuses(recoveredSessions)"))
        assertTrue(pendingStatusHolder.contains("conversationList.value = result.conversations"))
        assertFalse(pendingStatusHolder.contains("TaskErrorRecoveryPendingStore(appContext)"))
        assertFalse(pendingStatusHolder.contains("TaskErrorRecoveryPendingSyncUseCase("))
        assertFalse(pendingStatusHolder.contains("repository.interruptConversation("))

        assertTrue(useCase.contains("interruptConversation = repository::interruptConversation"))
        assertTrue(useCase.contains("interruptConversation(sessionId, accountId(), reason)"))
        assertTrue(useCase.contains("reason = ExecutionErrorExitReason"))
        assertTrue(useCase.contains("reason = ExecutionErrorRecoveredReason"))
        assertTrue(useCase.contains("logLabel = \"exit\""))
        assertTrue(useCase.contains("logLabel = \"recovery\""))
        assertTrue(useCase.contains("TaskConversationListStatusReducer.updateStatus"))
        assertTrue(useCase.contains("AccountIdentityProvider.accountId"))
        assertTrue(useCase.contains("synced pending execution error \$logLabel session="))
        assertTrue(useCase.contains("sync pending execution error \$logLabel failed session="))

        assertTrue(pendingStore.contains("PendingExecutionErrorExitSessionsKey"))
        assertTrue(pendingStore.contains("PendingExecutionErrorRecoveredSessionsKey"))
        assertTrue(pendingStore.contains("getSharedPreferences(\"index9_task_error_exit\""))
        assertTrue(pendingStore.contains("getStringSet(key, emptySet())"))
        assertTrue(pendingStore.contains("putStringSet(key, sessions)"))
        assertFalse(pendingStore.contains("MutableStateFlow"))
        assertFalse(pendingStore.contains("conversationList"))

        assertTrue(networkRetryController.contains("private val networkRegistrar: TaskErrorRecoveryNetworkCallbackRegistrar"))
        assertTrue(networkRetryController.contains("networkRegistrar.register(::onNetworkAvailable)"))
        assertTrue(networkRetryController.contains("networkRegistrar.unregister()"))
        assertTrue(networkRetryController.contains("network available, retry pending execution error status sync"))
        assertTrue(networkRetryController.contains("syncPendingExecutionErrorExitSessions()"))
        assertTrue(networkRetryController.contains("syncPendingExecutionErrorRecoveredSessions()"))
        assertTrue(networkRetryController.contains("loadConversations()"))
        assertFalse(networkRetryController.contains("android.content.Context"))
        assertFalse(networkRetryController.contains("android.net.ConnectivityManager"))
        assertFalse(networkRetryController.contains("android.net.Network"))
        assertFalse(networkRetryController.contains("ConnectivityManager.NetworkCallback()"))
        assertFalse(networkRetryController.contains("registerDefaultNetworkCallback("))
        assertFalse(networkRetryController.contains("unregisterNetworkCallback("))

        assertTrue(networkRegistrar.contains("internal class TaskErrorRecoveryNetworkCallbackRegistrar"))
        assertTrue(networkRegistrar.contains("appContext.getSystemService(Context.CONNECTIVITY_SERVICE)"))
        assertTrue(networkRegistrar.contains("ConnectivityManager.NetworkCallback()"))
        assertTrue(networkRegistrar.contains("override fun onAvailable(network: Network)"))
        assertTrue(networkRegistrar.contains("manager.registerDefaultNetworkCallback(callback)"))
        assertTrue(networkRegistrar.contains("manager.unregisterNetworkCallback(callback)"))
        assertTrue(networkRegistrar.contains("register task error network callback failed:"))
        assertTrue(networkRegistrar.contains("unregister task error network callback failed:"))
        assertFalse(networkRegistrar.contains("syncPendingExecutionErrorExitSessions()"))
        assertFalse(networkRegistrar.contains("syncPendingExecutionErrorRecoveredSessions()"))
        assertFalse(networkRegistrar.contains("loadConversations()"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }

    private fun String.countLiteral(token: String): Int = split(token).size - 1
}
