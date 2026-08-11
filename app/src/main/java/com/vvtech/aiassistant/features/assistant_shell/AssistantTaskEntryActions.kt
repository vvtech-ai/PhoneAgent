package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.shouldForceNewTaskVoiceEntryStart

internal class AssistantTaskEntryActionCallbacks(
    val shouldBlockOpenSingleFlow: () -> Boolean,
    val shouldBlockResumeSingleFlow: () -> Boolean,
    val onResetTaskConversationForNewEntry: () -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onOpenSingleFlowPage: () -> Unit,
    val onResumeSingleFlowPage: () -> Unit,
    val onOpenAssistantPage: () -> Unit,
    val onShowHomeComposer: () -> Unit,
    val onSubmitTextTask: (String) -> Unit,
    val onStartNewTextTask: (String) -> Unit
)

internal fun openAssistantSingleFlowEntry(
    state: AssistantTaskEntryState,
    initialCommand: String? = null,
    startWithVoice: Boolean = false,
    selectedContact: SelectedContactTaskContext? = null,
    callbacks: AssistantTaskEntryActionCallbacks
): Boolean {
    if (callbacks.shouldBlockOpenSingleFlow()) return false
    callbacks.onResetTaskConversationForNewEntry()
    callbacks.onClearLocalTaskItemsForRequirementEntry()
    val entryCommand = initialCommand?.trim().orEmpty()
    state.singleFlowInitialCommand = entryCommand
    state.singleFlowSelectedContact = selectedContact
    state.singleFlowStartInVoice = startWithVoice
    state.singleFlowResumeListeningOnly = false
    state.singleFlowForceNewVoiceEntryStart = shouldForceNewTaskVoiceEntryStart(
        startInVoice = startWithVoice,
        resumeListeningOnly = false,
        resumeExisting = false,
        initialCommand = entryCommand
    )
    state.bumpSingleFlowEntry()
    callbacks.onOpenSingleFlowPage()
    return true
}

internal fun restartAssistantSingleFlowEntry(
    state: AssistantTaskEntryState,
    callbacks: AssistantTaskEntryActionCallbacks
) {
    callbacks.onResetTaskConversationForNewEntry()
    callbacks.onClearLocalTaskItemsForRequirementEntry()
    state.bumpSingleFlowEntry()
}

internal fun resumeAssistantSingleFlowEntry(
    state: AssistantTaskEntryState,
    startListening: Boolean = false,
    callbacks: AssistantTaskEntryActionCallbacks
): Boolean {
    if (callbacks.shouldBlockResumeSingleFlow()) return false
    state.singleFlowInitialCommand = ""
    state.singleFlowSelectedContact = null
    state.singleFlowStartInVoice = startListening
    state.singleFlowResumeListeningOnly = startListening
    state.singleFlowForceNewVoiceEntryStart = false
    state.bumpSingleFlowEntry()
    callbacks.onResumeSingleFlowPage()
    return true
}

internal fun startAssistantTextTaskEntry(
    state: AssistantTaskEntryState,
    text: String,
    callbacks: AssistantTaskEntryActionCallbacks
): Boolean {
    val task = text.trim()
    if (task.isBlank()) return false
    state.taskTextDraft = ""
    callbacks.onStartNewTextTask(task)
    return true
}

internal fun submitAssistantTextTaskFlow(
    state: AssistantTaskEntryState,
    callbacks: AssistantTaskEntryActionCallbacks
): Boolean {
    val task = state.taskTextDraft.trim()
    if (task.isBlank()) return false
    if (callbacks.shouldBlockResumeSingleFlow()) return false
    if (!state.taskStarted) {
        return startAssistantTextTaskEntry(state, task, callbacks)
    }

    callbacks.onOpenAssistantPage()
    callbacks.onShowHomeComposer()
    state.taskStarted = true
    callbacks.onSubmitTextTask(task)
    state.taskUserText = task
    state.aiReplyVisible = false
    state.aiThinking = true
    state.clearRequirementSelectionState()
    state.taskTextDraft = ""
    return true
}

internal fun clearAssistantLocalTaskConversationState(
    callbacks: AssistantTaskEntryActionCallbacks
) {
    callbacks.onClearLocalTaskItemsForRequirementEntry()
}
