package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.finalPageForMainTab
import com.vvtech.aiassistant.features.assistant.finalPageRequiresIdentityBeforeAssistantEntry
import com.vvtech.aiassistant.features.assistant.resolveFinalSubPageTarget

internal data class AssistantMainTabSwitchState(
    val currentMainTab: FinalMainTab,
    val currentPage: FinalPage,
    val contactsPermissionGranted: Boolean,
    val taskStarted: Boolean
)

internal data class AssistantMainTabSwitchCallbacks(
    val onRequestContactsPermission: () -> Unit,
    val onOpenCallsDialSheet: () -> Unit,
    val onStartVoiceEntry: () -> Unit,
    val onApplyMainTab: (tab: FinalMainTab, page: FinalPage) -> Unit,
    val onHideCallsDialSheet: () -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val onOpenTasksTab: () -> Unit
)

internal fun switchAssistantMainTab(
    tab: FinalMainTab,
    state: AssistantMainTabSwitchState,
    callbacks: AssistantMainTabSwitchCallbacks
) {
    if (tab == FinalMainTab.Contacts && !state.contactsPermissionGranted) {
        callbacks.onRequestContactsPermission()
        return
    }
    if (tab == FinalMainTab.Assistant) {
        if (state.currentMainTab == FinalMainTab.Calls && state.currentPage == FinalPage.Calls) {
            callbacks.onOpenCallsDialSheet()
            return
        }
        callbacks.onStartVoiceEntry()
        return
    }
    callbacks.onApplyMainTab(tab, finalPageForMainTab(tab))
    callbacks.onHideCallsDialSheet()
    if (!state.taskStarted) {
        callbacks.onCloseHomeComposer()
    }
    if (tab == FinalMainTab.Tasks) {
        callbacks.onOpenTasksTab()
    }
}

internal data class AssistantSubPageOpenState(
    val pureVoiceMode: Boolean,
    val currentMainTab: FinalMainTab
)

internal data class AssistantSubPageOpenCallbacks(
    val shouldBlockAssistantEntry: (FinalPage) -> Boolean,
    val onApplySubPage: (previousTab: FinalMainTab, page: FinalPage) -> Unit
)

internal fun openAssistantSubPageWithPolicy(
    page: FinalPage,
    state: AssistantSubPageOpenState,
    callbacks: AssistantSubPageOpenCallbacks
) {
    val resolvedPage = resolveFinalSubPageTarget(page, state.pureVoiceMode)
    if (finalPageRequiresIdentityBeforeAssistantEntry(resolvedPage) &&
        callbacks.shouldBlockAssistantEntry(resolvedPage)
    ) {
        return
    }
    callbacks.onApplySubPage(state.currentMainTab, resolvedPage)
}

internal data class AssistantReturnToMainTabState(
    val previousMainTab: FinalMainTab
)

internal data class AssistantReturnToMainTabCallbacks(
    val shouldBlockAssistantEntry: (FinalPage) -> Boolean,
    val onGoHome: () -> Unit,
    val onApplyMainTab: (tab: FinalMainTab, page: FinalPage) -> Unit
)

internal fun backToAssistantMainTab(
    state: AssistantReturnToMainTabState,
    callbacks: AssistantReturnToMainTabCallbacks
) {
    val targetTab = state.previousMainTab
    val targetPage = finalPageForMainTab(targetTab)
    if (finalPageRequiresIdentityBeforeAssistantEntry(targetPage) &&
        callbacks.shouldBlockAssistantEntry(targetPage)
    ) {
        callbacks.onGoHome()
        return
    }
    callbacks.onApplyMainTab(targetTab, targetPage)
}

internal data class AssistantTaskFlowReturnState(
    val previousMainTab: FinalMainTab
)

internal data class AssistantTaskFlowResetCallbacks(
    val onInterruptTaskConversationForUserClose: (String) -> Unit,
    val onClearLocalTaskConversationState: () -> Unit,
    val onRestorePreviousMainTab: () -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val onRefreshTasks: () -> Unit,
    val onLoadConversations: () -> Unit
)

internal fun resetAssistantTaskFlow(
    state: AssistantTaskFlowReturnState,
    callbacks: AssistantTaskFlowResetCallbacks
) {
    callbacks.onInterruptTaskConversationForUserClose("reset_task_flow")
    callbacks.onClearLocalTaskConversationState()
    callbacks.onRestorePreviousMainTab()
    callbacks.onCloseHomeComposer()
    if (state.previousMainTab == FinalMainTab.Tasks) {
        callbacks.onRefreshTasks()
        callbacks.onLoadConversations()
    }
}

internal data class AssistantTaskFlowPauseCallbacks(
    val nextDeferredRefreshId: (String) -> String,
    val onPauseTaskConversationAndResetLocalUi: (reason: String, reloadConversations: Boolean) -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onApplyMainTab: (tab: FinalMainTab, page: FinalPage) -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val onScheduleTaskRefreshAfterClose: (String) -> Unit
)

internal fun pauseAssistantTaskFlowAndReturnToPreviousTab(
    source: String,
    state: AssistantTaskFlowReturnState,
    callbacks: AssistantTaskFlowPauseCallbacks
) {
    val closeId = callbacks.nextDeferredRefreshId(source)
    val targetTab = state.previousMainTab
    val targetPage = finalPageForMainTab(targetTab)
    callbacks.onPauseTaskConversationAndResetLocalUi("close:$closeId", false)
    callbacks.onClearLocalTaskItemsForRequirementEntry()
    callbacks.onApplyMainTab(targetTab, targetPage)
    callbacks.onCloseHomeComposer()
    if (targetTab == FinalMainTab.Tasks) {
        callbacks.onScheduleTaskRefreshAfterClose(closeId)
    }
}

internal data class AssistantSingleFlowBackCallbacks(
    val onPauseTaskConversationAndResetLocalUi: (reason: String, reloadConversations: Boolean) -> Unit,
    val onScheduleTaskRefreshAfterClose: (String) -> Unit,
    val onApplyMainTab: (tab: FinalMainTab, page: FinalPage) -> Unit
)

internal fun pauseAssistantSingleFlowForSystemBack(
    closeId: String,
    targetTab: FinalMainTab,
    targetPage: FinalPage,
    callbacks: AssistantSingleFlowBackCallbacks
) {
    callbacks.onPauseTaskConversationAndResetLocalUi("back:$closeId", false)
    if (targetTab == FinalMainTab.Tasks) {
        callbacks.onScheduleTaskRefreshAfterClose(closeId)
    }
    callbacks.onApplyMainTab(targetTab, targetPage)
}

internal data class AssistantResultReturnCallbacks(
    val onReturnToHomeFromResultPage: () -> Unit,
    val onClearLocalTaskConversationState: () -> Unit,
    val onGoHome: () -> Unit,
    val onCloseHomeComposer: () -> Unit
)

internal fun returnAssistantResultToHome(callbacks: AssistantResultReturnCallbacks) {
    callbacks.onReturnToHomeFromResultPage()
    callbacks.onClearLocalTaskConversationState()
    callbacks.onGoHome()
    callbacks.onCloseHomeComposer()
}
