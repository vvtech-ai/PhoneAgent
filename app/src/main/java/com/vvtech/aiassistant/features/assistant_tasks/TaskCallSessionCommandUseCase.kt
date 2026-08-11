package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallHandoffRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusRequest
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.data.repository.AssistantRepository

internal enum class TaskCallSessionHandoffCommand {
    RequestHumanTakeover,
    ReleaseToAi,
    HangUp
}

internal data class TaskCallSessionHandoffRequestPlan(
    val command: TaskCallSessionHandoffCommand,
    val request: CallHandoffRequest
)

internal data class TaskCallSessionStatusRequestPlan(
    val request: CallSessionStatusRequest
)

internal fun taskCallSessionHandoffRequestPlan(
    command: TaskCallSessionHandoffCommand,
    userId: String,
    taskId: String?,
    callId: String?
): TaskCallSessionHandoffRequestPlan {
    return TaskCallSessionHandoffRequestPlan(
        command = command,
        request = CallHandoffRequest(
            userId = userId,
            taskId = taskId,
            callId = callId,
            reason = command.reason
        )
    )
}

internal fun taskCallSessionStatusRequestPlan(
    userId: String,
    taskId: String?,
    callId: String?
): TaskCallSessionStatusRequestPlan {
    return TaskCallSessionStatusRequestPlan(
        request = CallSessionStatusRequest(
            userId = userId,
            taskId = taskId,
            callId = callId
        )
    )
}

internal class TaskCallSessionCommandUseCase(
    private val repository: AssistantRepository
) {
    suspend fun requestHumanTakeover(
        userId: String,
        taskId: String?,
        callId: String?
    ): CallSessionStatusResponse {
        return repository.requestCallHandoff(
            taskCallSessionHandoffRequestPlan(
                command = TaskCallSessionHandoffCommand.RequestHumanTakeover,
                userId = userId,
                taskId = taskId,
                callId = callId
            ).request
        )
    }

    suspend fun releaseToAi(
        userId: String,
        taskId: String?,
        callId: String?
    ): CallSessionStatusResponse {
        return repository.releaseCallHandoff(
            taskCallSessionHandoffRequestPlan(
                command = TaskCallSessionHandoffCommand.ReleaseToAi,
                userId = userId,
                taskId = taskId,
                callId = callId
            ).request
        )
    }

    suspend fun hangUp(
        userId: String,
        taskId: String?,
        callId: String?
    ): CallSessionStatusResponse {
        return repository.hangUpCall(
            taskCallSessionHandoffRequestPlan(
                command = TaskCallSessionHandoffCommand.HangUp,
                userId = userId,
                taskId = taskId,
                callId = callId
            ).request
        )
    }

    suspend fun refreshStatus(
        userId: String,
        taskId: String?,
        callId: String?
    ): CallSessionStatusResponse {
        return repository.getCallSessionStatus(
            taskCallSessionStatusRequestPlan(
                userId = userId,
                taskId = taskId,
                callId = callId
            ).request
        )
    }
}

private val TaskCallSessionHandoffCommand.reason: String
    get() = when (this) {
        TaskCallSessionHandoffCommand.RequestHumanTakeover -> "用户在 App 端请求人工接管"
        TaskCallSessionHandoffCommand.ReleaseToAi -> "用户在 App 端请求切回 AI 代打"
        TaskCallSessionHandoffCommand.HangUp -> "用户在 App 端挂断通话"
    }
