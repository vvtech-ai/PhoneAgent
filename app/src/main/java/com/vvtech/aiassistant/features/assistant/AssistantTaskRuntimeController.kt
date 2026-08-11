package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class AssistantTaskRuntimeDeps(
    val assistantRepository: AssistantRepository,
    val taskRepository: TaskRepository,
    val scope: CoroutineScope
)

internal class AssistantTaskRuntimeState(
    val records: MutableList<FinalTaskRecord>,
    val loading: MutableState<Boolean>,
    val error: MutableState<String?>,
    val pendingDeferredRefreshCloseId: MutableState<String?>
)

internal class AssistantTaskRuntimeController(
    private val deps: AssistantTaskRuntimeDeps,
    private val state: AssistantTaskRuntimeState
) {
    val records: List<FinalTaskRecord>
        get() = state.records

    var loading by state.loading
    var error by state.error
    var pendingDeferredRefreshCloseId by state.pendingDeferredRefreshCloseId

    @Suppress("UNUSED_PARAMETER")
    fun refresh(reason: String = "default", force: Boolean = false) {
        if (loading && !force) {
            logTaskRefresh(
                eventType = "task_refresh_skipped",
                stateBefore = "loading",
                stateAfter = "loading",
                reason = "already_loading",
                attributes = mapOf(
                    "requestedReason" to reason,
                    "force" to force.toString(),
                    "recordCount" to records.size.toString()
                )
            )
            return
        }
        val stateBefore = if (loading) "loading" else "idle"
        logTaskRefresh(
            eventType = "task_refresh_started",
            stateBefore = stateBefore,
            stateAfter = "loading",
            reason = reason,
            attributes = mapOf(
                "force" to force.toString(),
                "recordCount" to records.size.toString()
            )
        )
        loading = true
        error = null
        deps.scope.launch {
            val accountId = AccountIdentityProvider.accountId
            val assistantHistoryResult = runCatching {
                deps.assistantRepository.loadSessionHistory(accountId).tasks
            }
            val legacyTaskResult = runCatching {
                deps.taskRepository.listTasks(accountId)
            }
            if (assistantHistoryResult.isSuccess || legacyTaskResult.isSuccess) {
                val assistantHistory = assistantHistoryResult.getOrDefault(emptyList())
                val assistantTaskIds = assistantHistory.map { it.taskId }.toSet()
                val legacyTasks = legacyTaskResult.getOrDefault(emptyList())
                    .filterNot { assistantTaskIds.contains(it.taskId) }
                val mergedRecords = (assistantHistory.map { it.toFinalTaskRecord() } +
                    legacyTasks.map { it.toFinalTaskRecord() })
                    .sortedByDescending { finalTaskRecordSortEpochMillis(it) }
                state.records.clear()
                state.records.addAll(mergedRecords)
                logTaskRefresh(
                    eventType = "task_refresh_completed",
                    stateBefore = "loading",
                    stateAfter = "loaded",
                    reason = reason,
                    attributes = mapOf(
                        "assistantTaskCount" to assistantHistory.size.toString(),
                        "legacyTaskCount" to legacyTasks.size.toString(),
                        "mergedRecordCount" to mergedRecords.size.toString(),
                        "assistantSource" to sourceState(assistantHistoryResult.isSuccess),
                        "legacySource" to sourceState(legacyTaskResult.isSuccess)
                    )
                )
            } else {
                error = assistantHistoryResult.exceptionOrNull()?.message
                    ?: legacyTaskResult.exceptionOrNull()?.message
                    ?: "Task list load failed"
                logTaskRefresh(
                    eventType = "task_refresh_failed",
                    stateBefore = "loading",
                    stateAfter = "error",
                    reason = "task_list_load_failed",
                    attributes = mapOf(
                        "requestedReason" to reason,
                        "assistantFailure" to assistantHistoryResult.exceptionOrNull()?.javaClass?.simpleName,
                        "legacyFailure" to legacyTaskResult.exceptionOrNull()?.javaClass?.simpleName
                    )
                )
            }
            loading = false
        }
    }

    fun scheduleRefreshAfterClose(closeId: String) {
        pendingDeferredRefreshCloseId = closeId
    }

    fun clearPendingDeferredRefreshCloseId() {
        pendingDeferredRefreshCloseId = null
    }

    private fun logTaskRefresh(
        eventType: String,
        stateBefore: String,
        stateAfter: String,
        reason: String?,
        attributes: Map<String, String?>
    ) {
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.TASK,
                eventType = eventType,
                stateBefore = stateBefore,
                stateAfter = stateAfter,
                reason = reason,
                attributes = attributes
            )
        )
    }

    private fun sourceState(success: Boolean): String {
        return if (success) "success" else "failed"
    }
}

@Composable
internal fun rememberAssistantTaskRuntimeController(
    deps: AssistantTaskRuntimeDeps
): AssistantTaskRuntimeController {
    val state = AssistantTaskRuntimeState(
        records = remember { mutableStateListOf() },
        loading = rememberSaveable { mutableStateOf(false) },
        error = rememberSaveable { mutableStateOf<String?>(null) },
        pendingDeferredRefreshCloseId = rememberSaveable { mutableStateOf<String?>(null) }
    )
    return remember(deps.assistantRepository, deps.taskRepository, deps.scope) {
        AssistantTaskRuntimeController(deps, state)
    }
}
