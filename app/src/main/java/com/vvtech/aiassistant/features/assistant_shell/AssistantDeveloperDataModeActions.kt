package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalPage

internal class AssistantDeveloperDataModeActionState(
    val activeAccountId: String,
    val contactsPermissionGranted: Boolean,
    val currentPage: FinalPage
)

internal class AssistantDeveloperDataModeActionCallbacks(
    val onApplyDeveloperDataMode: (DeveloperDataMode) -> Unit,
    val onClearCallRecordsForAccount: (String) -> Unit,
    val onRefreshTasks: () -> Unit,
    val onApplyContactDeveloperDataMode: (DeveloperDataMode, Boolean, FinalPage) -> Unit
)

internal fun applyAssistantDeveloperDataMode(
    mode: DeveloperDataMode,
    state: AssistantDeveloperDataModeActionState,
    callbacks: AssistantDeveloperDataModeActionCallbacks
) {
    callbacks.onApplyDeveloperDataMode(mode)
    callbacks.onClearCallRecordsForAccount(state.activeAccountId)
    if (mode == DeveloperDataMode.Filled) {
        callbacks.onRefreshTasks()
    }
    callbacks.onApplyContactDeveloperDataMode(
        mode,
        state.contactsPermissionGranted,
        state.currentPage
    )
}
