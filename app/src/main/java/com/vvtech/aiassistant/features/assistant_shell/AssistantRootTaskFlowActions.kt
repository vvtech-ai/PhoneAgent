package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.logging.AppFileLogger

private const val VoiceEntryLogTag = "VoiceEntryPerf"

internal data class AssistantRootTaskFlowActionDeps(
    val taskEntry: AssistantTaskEntryState,
    val previousMainTabProvider: () -> FinalMainTab,
    val currentPageProvider: () -> FinalPage,
    val activeAccountIdProvider: () -> String,
    val contactsPermissionGrantedProvider: () -> Boolean,
    val shouldBlockOpenSingleFlow: () -> Boolean,
    val shouldBlockResumeSingleFlow: () -> Boolean,
    val onResetTaskConversationForNewEntry: () -> Unit,
    val onClearLocalTaskItemsForRequirementEntry: () -> Unit,
    val onOpenSingleFlowPage: () -> Unit,
    val onResumeSingleFlowPage: () -> Unit,
    val onOpenAssistantPage: () -> Unit,
    val onShowHomeComposer: () -> Unit,
    val onSubmitTextTask: (String) -> Unit,
    val onStartNewTextTask: (String) -> Unit,
    val onInterruptTaskConversationForUserClose: (String) -> Unit,
    val onRestorePreviousMainTab: () -> Unit,
    val onCloseHomeComposer: () -> Unit,
    val onRefreshTasks: () -> Unit,
    val onLoadConversations: () -> Unit,
    val nextDeferredRefreshId: (String) -> String,
    val onPauseTaskConversationAndResetLocalUi: (reason: String, reloadConversations: Boolean) -> Unit,
    val onApplyMainTab: (tab: FinalMainTab, page: FinalPage) -> Unit,
    val onScheduleTaskRefreshAfterClose: (String) -> Unit,
    val onReturnToHomeFromResultPage: () -> Unit,
    val onGoHome: () -> Unit,
    val onApplyDeveloperDataMode: (DeveloperDataMode) -> Unit,
    val onClearCallRecordsForAccount: (String) -> Unit,
    val onApplyContactDeveloperDataMode: (DeveloperDataMode, Boolean, FinalPage) -> Unit
)

internal class AssistantRootTaskFlowActions(
    private val deps: AssistantRootTaskFlowActionDeps
) {
    private val taskEntryCallbacks = AssistantTaskEntryActionCallbacks(
        shouldBlockOpenSingleFlow = deps.shouldBlockOpenSingleFlow,
        shouldBlockResumeSingleFlow = deps.shouldBlockResumeSingleFlow,
        onResetTaskConversationForNewEntry = deps.onResetTaskConversationForNewEntry,
        onClearLocalTaskItemsForRequirementEntry = deps.onClearLocalTaskItemsForRequirementEntry,
        onOpenSingleFlowPage = deps.onOpenSingleFlowPage,
        onResumeSingleFlowPage = deps.onResumeSingleFlowPage,
        onOpenAssistantPage = deps.onOpenAssistantPage,
        onShowHomeComposer = deps.onShowHomeComposer,
        onSubmitTextTask = deps.onSubmitTextTask,
        onStartNewTextTask = deps.onStartNewTextTask
    )

    private val resetCallbacks = AssistantTaskFlowResetCallbacks(
        onInterruptTaskConversationForUserClose = deps.onInterruptTaskConversationForUserClose,
        onClearLocalTaskConversationState = ::clearLocalTaskConversationState,
        onRestorePreviousMainTab = deps.onRestorePreviousMainTab,
        onCloseHomeComposer = deps.onCloseHomeComposer,
        onRefreshTasks = deps.onRefreshTasks,
        onLoadConversations = deps.onLoadConversations
    )

    private val pauseCallbacks = AssistantTaskFlowPauseCallbacks(
        nextDeferredRefreshId = deps.nextDeferredRefreshId,
        onPauseTaskConversationAndResetLocalUi = deps.onPauseTaskConversationAndResetLocalUi,
        onClearLocalTaskItemsForRequirementEntry = deps.onClearLocalTaskItemsForRequirementEntry,
        onApplyMainTab = deps.onApplyMainTab,
        onCloseHomeComposer = deps.onCloseHomeComposer,
        onScheduleTaskRefreshAfterClose = deps.onScheduleTaskRefreshAfterClose
    )

    private val resultReturnCallbacks = AssistantResultReturnCallbacks(
        onReturnToHomeFromResultPage = deps.onReturnToHomeFromResultPage,
        onClearLocalTaskConversationState = ::clearLocalTaskConversationState,
        onGoHome = deps.onGoHome,
        onCloseHomeComposer = deps.onCloseHomeComposer
    )

    private val developerDataModeCallbacks = AssistantDeveloperDataModeActionCallbacks(
        onApplyDeveloperDataMode = deps.onApplyDeveloperDataMode,
        onClearCallRecordsForAccount = deps.onClearCallRecordsForAccount,
        onRefreshTasks = deps.onRefreshTasks,
        onApplyContactDeveloperDataMode = deps.onApplyContactDeveloperDataMode
    )

    fun openSingleFlow(
        initialCommand: String? = null,
        startWithVoice: Boolean = false,
        selectedContact: SelectedContactTaskContext? = null
    ): Boolean =
        openAssistantSingleFlowEntry(
            state = deps.taskEntry,
            initialCommand = initialCommand,
            startWithVoice = startWithVoice,
            selectedContact = selectedContact,
            callbacks = taskEntryCallbacks
        )

    fun restartSingleFlow() {
        restartAssistantSingleFlowEntry(deps.taskEntry, taskEntryCallbacks)
    }

    fun goHomePreservingSession() {
        deps.onGoHome()
        deps.onCloseHomeComposer()
    }

    fun resumeSingleFlow(startListening: Boolean = false): Boolean =
        resumeAssistantSingleFlowEntry(
            state = deps.taskEntry,
            startListening = startListening,
            callbacks = taskEntryCallbacks
        )

    fun startTaskFlow(text: String): Boolean =
        startAssistantTextTaskEntry(deps.taskEntry, text, taskEntryCallbacks)

    fun submitTextTaskFlow(): Boolean =
        submitAssistantTextTaskFlow(deps.taskEntry, taskEntryCallbacks)

    fun clearLocalTaskConversationState() {
        clearAssistantLocalTaskConversationState(taskEntryCallbacks)
    }

    fun resetTaskFlow() {
        resetAssistantTaskFlow(
            state = AssistantTaskFlowReturnState(previousMainTab = deps.previousMainTabProvider()),
            callbacks = resetCallbacks
        )
    }

    fun pauseTaskFlowAndReturnToPreviousTab(source: String = "unknown") {
        val invalidatedEntryKey = deps.taskEntry.invalidatePendingSingleFlowEntry()
        AppFileLogger.i(
            VoiceEntryLogTag,
            "VOICE_ENTRY_INVALIDATE source=$source entryKey=$invalidatedEntryKey"
        )
        pauseAssistantTaskFlowAndReturnToPreviousTab(
            source = source,
            state = AssistantTaskFlowReturnState(previousMainTab = deps.previousMainTabProvider()),
            callbacks = pauseCallbacks
        )
    }

    fun returnResultToHome() {
        returnAssistantResultToHome(resultReturnCallbacks)
    }

    fun applyDeveloperDataMode(mode: DeveloperDataMode) {
        applyAssistantDeveloperDataMode(
            mode = mode,
            state = AssistantDeveloperDataModeActionState(
                activeAccountId = deps.activeAccountIdProvider(),
                contactsPermissionGranted = deps.contactsPermissionGrantedProvider(),
                currentPage = deps.currentPageProvider()
            ),
            callbacks = developerDataModeCallbacks
        )
    }
}
