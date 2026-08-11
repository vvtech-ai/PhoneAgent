package com.vvtech.aiassistant.features.assistant_tasks

internal object TaskCallSessionStatusApplyControllerFactory {
    fun create(
        state: TaskCallSessionStatusApplyStateAccess,
        runtime: TaskCallSessionStatusApplyRuntimeActions,
        terminalRuntime: TaskCallSessionTerminalStatusRuntimeActions,
        logging: TaskCallSessionStatusApplyLogging
    ): TaskCallSessionStatusApplyController {
        val terminalController = TaskCallSessionTerminalStatusController(
            TaskCallSessionTerminalStatusControllerDeps(
                state = state,
                runtime = terminalRuntime,
                logging = logging
            )
        )
        return TaskCallSessionStatusApplyController(
            TaskCallSessionStatusApplyControllerDeps(
                state = state,
                runtime = runtime,
                logging = logging,
                terminalStatusController = terminalController
            )
        )
    }
}
