package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

private const val CallSessionPollingIntervalMillis = 1500L

internal data class TaskCallSessionPollingControllerDeps(
    val scope: CoroutineScope,
    val userIdProvider: () -> String,
    val commandUseCase: TaskCallSessionCommandUseCase,
    val stateProvider: () -> Index9AssistantUiState,
    val pendingAiCallLaunchProvider: () -> Boolean,
    val getPollingJob: () -> Job?,
    val setPollingJob: (Job?) -> Unit,
    val logDiag: (String) -> Unit,
    val applyStatus: (CallSessionStatusResponse) -> Unit,
    val onRefreshFailure: (Throwable) -> Unit,
    val audioGateSnapshot: () -> String
)

internal class TaskCallSessionPollingController(
    private val deps: TaskCallSessionPollingControllerDeps
) {
    fun start() {
        logPolling("CALL_POLLING_STARTED", "started", "polling_requested")
        deps.logDiag("startCallSessionPolling_before")
        deps.getPollingJob()?.cancel()
        deps.setPollingJob(
            deps.scope.launch {
                while (isActive && shouldKeepPolling(deps.stateProvider())) {
                    refresh()
                    delay(CallSessionPollingIntervalMillis)
                }
                deps.logDiag("callSessionPolling_loop_exit active=$isActive")
            }
        )
        deps.logDiag("startCallSessionPolling_after")
    }

    fun stop() {
        logPolling("CALL_POLLING_STOPPED", "stopped", "polling_stop_requested")
        deps.logDiag("stopCallSessionPolling")
        deps.getPollingJob()?.cancel()
        deps.setPollingJob(null)
    }

    fun refresh() {
        val state = deps.stateProvider()
        if (state.taskId.isNullOrBlank() && state.currentCallId.isNullOrBlank()) {
            logPolling(
                eventType = "CALL_POLLING_SKIPPED",
                result = "skipped",
                reason = "missing_task_and_call"
            )
            deps.logDiag("refreshCallSessionStatus_skip_no_task_or_call")
            return
        }
        deps.logDiag("refreshCallSessionStatus_request")
        deps.scope.launch {
            runCatching {
                deps.commandUseCase.refreshStatus(
                    userId = deps.userIdProvider(),
                    taskId = state.taskId,
                    callId = state.currentCallId
                )
            }.onSuccess { response ->
                deps.applyStatus(response)
            }.onFailure { throwable ->
                deps.onRefreshFailure(throwable)
                RuntimeStateLogger.warn(
                    RuntimeStateLogEvent(
                        domain = RuntimeStateLogDomain.CALL,
                        eventType = "CALL_POLLING_FAILED",
                        taskId = state.taskId,
                        callId = state.currentCallId,
                        result = "failed",
                        reason = "status_refresh_failure",
                        attributes = mapOf(
                            "exceptionType" to throwable.javaClass.simpleName
                        )
                    ),
                    throwable
                )
                AppFileLogger.w(
                    "CALL_PAGE_DIAG",
                    "refreshCallSessionStatus_failed message=${throwable.message} " +
                        deps.audioGateSnapshot()
                )
            }
        }
    }

    fun shouldKeepPolling(state: Index9AssistantUiState): Boolean {
        return taskCallSessionShouldKeepPolling(
            state = state,
            pendingAiCallLaunch = deps.pendingAiCallLaunchProvider()
        )
    }

    private fun logPolling(
        eventType: String,
        result: String,
        reason: String
    ) {
        val state = deps.stateProvider()
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.CALL,
                eventType = eventType,
                taskId = state.taskId,
                callId = state.currentCallId,
                result = result,
                reason = reason,
                attributes = mapOf(
                    "showAiCallPage" to state.showAiCallPage.toString(),
                    "pendingLaunch" to deps.pendingAiCallLaunchProvider().toString()
                )
            )
        )
    }
}

internal fun taskCallSessionShouldKeepPolling(
    state: Index9AssistantUiState,
    pendingAiCallLaunch: Boolean
): Boolean {
    return state.taskId != null &&
        (state.currentCallId != null || state.showAiCallPage || pendingAiCallLaunch)
}
