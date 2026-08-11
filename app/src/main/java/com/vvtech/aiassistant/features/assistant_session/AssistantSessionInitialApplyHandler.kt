package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.viewmodel.isTerminalTaskStatus

internal data class AssistantSessionInitialApplyHandlerDeps(
    val stateHolder: AssistantSessionInitialApplyStateHolder,
    val state: AssistantSessionInitialApplyStateAccess,
    val actions: AssistantSessionInitialApplyActions
)

internal data class AssistantSessionInitialApplyStateAccess(
    val pendingAiCallLaunch: () -> Boolean,
    val setPendingAiCallLaunch: (Boolean) -> Unit,
    val setPendingFreshTask: (Boolean) -> Unit
)

internal data class AssistantSessionInitialApplyActions(
    val applyNonTerminalSession: (AssistantSessionResponse) -> Unit,
    val resetToIdleHome: () -> Unit,
    val refreshHistory: () -> Unit
)

internal class AssistantSessionInitialApplyHandler(
    private val deps: AssistantSessionInitialApplyHandlerDeps
) {
    fun apply(session: AssistantSessionResponse) {
        if (isTerminalTaskStatus(session.session.taskStatus)) {
            deps.state.setPendingFreshTask(false)
            if (shouldPreserveTerminalResult(session)) {
                preserveTerminalResult(session)
                deps.actions.refreshHistory()
                return
            }
            deps.actions.resetToIdleHome()
            deps.actions.refreshHistory()
            return
        }
        deps.actions.applyNonTerminalSession(session)
    }

    fun shouldPreserveTerminalResult(session: AssistantSessionResponse): Boolean {
        return deps.stateHolder.shouldPreserveTerminalResult(
            session = session,
            pendingAiCallLaunch = deps.state.pendingAiCallLaunch()
        )
    }

    fun preserveTerminalResult(session: AssistantSessionResponse) {
        deps.state.setPendingAiCallLaunch(false)
        deps.stateHolder.preserveTerminalResult(session)
    }
}
