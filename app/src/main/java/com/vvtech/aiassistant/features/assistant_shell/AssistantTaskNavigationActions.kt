package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalPage

internal data class AssistantTaskPageNavigationState(
    val activeSessionId: String?,
    val hasLocalConversationSteps: Boolean,
    val useSingleFlowConversation: Boolean
)

internal data class AssistantTaskPageNavigationCallbacks(
    val onResumeConversation: (sessionId: String, onFinished: () -> Unit) -> Unit,
    val onResumeSingleFlow: (startListening: Boolean) -> Unit,
    val onOpenSingleFlow: (initialCommand: String, startWithVoice: Boolean) -> Unit,
    val onOpenSubPage: (FinalPage) -> Unit
)

internal fun resumeCurrentAssistantTaskConversation(
    state: AssistantTaskPageNavigationState,
    callbacks: AssistantTaskPageNavigationCallbacks
) {
    val sessionId = state.activeSessionId
    if (!sessionId.isNullOrBlank() && !state.hasLocalConversationSteps) {
        callbacks.onResumeConversation(sessionId) {
            callbacks.onResumeSingleFlow(false)
        }
        return
    }
    callbacks.onResumeSingleFlow(false)
}

internal fun openAssistantTaskConversation(
    sessionId: String,
    callbacks: AssistantTaskPageNavigationCallbacks
) {
    callbacks.onResumeConversation(sessionId) {
        callbacks.onResumeSingleFlow(false)
    }
}

internal fun openAssistantTaskResult(callbacks: AssistantTaskPageNavigationCallbacks) {
    callbacks.onResumeSingleFlow(false)
}

internal fun followUpAssistantTask(
    state: AssistantTaskPageNavigationState,
    callbacks: AssistantTaskPageNavigationCallbacks
) {
    if (state.useSingleFlowConversation) {
        callbacks.onOpenSingleFlow("", true)
    } else {
        callbacks.onOpenSubPage(FinalPage.Assistant)
    }
}
