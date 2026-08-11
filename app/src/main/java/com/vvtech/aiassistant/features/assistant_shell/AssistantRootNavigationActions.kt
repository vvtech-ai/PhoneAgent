package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalHomeNotificationItem
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage

internal data class AssistantRootNavigationActionDeps(
    val state: AssistantRootNavigationStateProviders,
    val taskTab: AssistantRootNavigationTaskTabDeps,
    val callbacks: AssistantRootNavigationActionCallbacks
)

internal data class AssistantRootNavigationStateProviders(
    val currentMainTab: () -> FinalMainTab,
    val currentPage: () -> FinalPage,
    val previousMainTab: () -> FinalMainTab,
    val pureVoiceMode: () -> Boolean,
    val contactsPermissionGranted: () -> Boolean,
    val taskStarted: () -> Boolean
)

internal data class AssistantRootNavigationTaskTabDeps(
    val readState: AssistantHomeNotificationReadState,
    val pendingNotificationsProvider: () -> List<FinalHomeNotificationItem>,
    val onRefreshTasks: () -> Unit,
    val onLoadConversations: () -> Unit
)

internal data class AssistantRootNavigationActionCallbacks(
    val onRequestContactsPermission: () -> Unit,
    val onOpenCallsDialSheet: () -> Unit,
    val onStartVoiceEntry: () -> Unit,
    val onApplyMainTab: (tab: FinalMainTab, page: FinalPage) -> Unit,
    val onHideCallsDialSheet: () -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val shouldBlockAssistantEntry: (FinalPage) -> Boolean,
    val onApplySubPage: (previousTab: FinalMainTab, page: FinalPage) -> Unit,
    val onGoHome: () -> Unit
)

internal class AssistantRootNavigationActions(
    private val deps: AssistantRootNavigationActionDeps
) {
    private val mainTabCallbacks = AssistantMainTabSwitchCallbacks(
        onRequestContactsPermission = deps.callbacks.onRequestContactsPermission,
        onOpenCallsDialSheet = deps.callbacks.onOpenCallsDialSheet,
        onStartVoiceEntry = deps.callbacks.onStartVoiceEntry,
        onApplyMainTab = deps.callbacks.onApplyMainTab,
        onHideCallsDialSheet = deps.callbacks.onHideCallsDialSheet,
        onCloseHomeComposer = deps.callbacks.onCloseHomeComposer,
        onOpenTasksTab = ::openTasksTab
    )

    private val subPageCallbacks = AssistantSubPageOpenCallbacks(
        shouldBlockAssistantEntry = deps.callbacks.shouldBlockAssistantEntry,
        onApplySubPage = deps.callbacks.onApplySubPage
    )

    private val returnToMainTabCallbacks = AssistantReturnToMainTabCallbacks(
        shouldBlockAssistantEntry = deps.callbacks.shouldBlockAssistantEntry,
        onGoHome = deps.callbacks.onGoHome,
        onApplyMainTab = deps.callbacks.onApplyMainTab
    )

    fun switchMainTab(tab: FinalMainTab) {
        switchAssistantMainTab(
            tab = tab,
            state = AssistantMainTabSwitchState(
                currentMainTab = deps.state.currentMainTab(),
                currentPage = deps.state.currentPage(),
                contactsPermissionGranted = deps.state.contactsPermissionGranted(),
                taskStarted = deps.state.taskStarted()
            ),
            callbacks = mainTabCallbacks
        )
    }

    fun openSubPage(page: FinalPage) {
        openAssistantSubPageWithPolicy(
            page = page,
            state = AssistantSubPageOpenState(
                pureVoiceMode = deps.state.pureVoiceMode(),
                currentMainTab = deps.state.currentMainTab()
            ),
            callbacks = subPageCallbacks
        )
    }

    fun backToMainTab() {
        backToAssistantMainTab(
            state = AssistantReturnToMainTabState(previousMainTab = deps.state.previousMainTab()),
            callbacks = returnToMainTabCallbacks
        )
    }

    private fun openTasksTab() {
        AssistantHomeNotificationReadActions.markPendingRead(
            readState = deps.taskTab.readState,
            pendingNotifications = deps.taskTab.pendingNotificationsProvider()
        )
        deps.taskTab.onRefreshTasks()
        deps.taskTab.onLoadConversations()
    }
}
