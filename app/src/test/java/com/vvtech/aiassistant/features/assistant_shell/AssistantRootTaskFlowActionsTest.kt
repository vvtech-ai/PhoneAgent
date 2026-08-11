package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootTaskFlowActionsTest {
    @Test
    fun rootDelegatesTaskFlowWrappersToShellAction() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootTaskFlowActions.kt"
        ).readText(Charsets.UTF_8)
        val actionGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt"
        ).readText(Charsets.UTF_8)
        val pageHostSecondaryFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostSecondaryArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val pageHostAssistantFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val pageHostMainFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("val rootTaskFlowActions = rootActionGraph.taskFlow"))
        assertFalse(root.contains("AssistantRootTaskFlowActions("))
        assertFalse(root.contains("AssistantRootTaskFlowActionDeps("))
        assertTrue(actionGraph.contains("AssistantRootTaskFlowActions("))
        assertTrue(actionGraph.contains("AssistantRootTaskFlowActionDeps("))
        assertTrue(root.contains("taskFlow = rootTaskFlowActions"))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow.openSingleFlow("))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow::restartSingleFlow"))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow::goHomePreservingSession"))
        assertTrue(pageHostAssistantFactory.contains("onSendText = actions.taskFlow::submitTextTaskFlow"))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow.startTaskFlow(it)"))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow::returnResultToHome"))
        assertFalse(root.contains("taskFlowActions = rootTaskFlowActions"))
        assertTrue(hostShell.contains("taskFlowActions = actions.taskFlow"))

        assertFalse(root.contains("fun openSingleFlow("))
        assertFalse(root.contains("fun restartSingleFlow("))
        assertFalse(root.contains("fun goHomePreservingSession("))
        assertFalse(root.contains("fun resumeSingleFlow("))
        assertFalse(root.contains("fun startTaskFlow("))
        assertFalse(root.contains("fun submitTextTaskFlow("))
        assertFalse(root.contains("fun clearLocalTaskConversationState("))
        assertFalse(root.contains("fun resetTaskFlow("))
        assertFalse(root.contains("fun pauseTaskFlowAndReturnToPreviousTab("))
        assertFalse(root.contains("fun returnResultToHome("))
        assertFalse(root.contains("fun applyDeveloperDataMode("))
        assertFalse(root.contains("val taskEntryActionCallbacks = AssistantTaskEntryActionCallbacks("))
        assertFalse(root.contains("val taskFlowResetCallbacks = AssistantTaskFlowResetCallbacks("))
        assertFalse(root.contains("val taskFlowPauseCallbacks = AssistantTaskFlowPauseCallbacks("))
        assertFalse(root.contains("val resultReturnCallbacks = AssistantResultReturnCallbacks("))
        assertFalse(root.contains("val developerDataModeActionCallbacks = AssistantDeveloperDataModeActionCallbacks("))
        assertFalse(root.contains("openAssistantSingleFlowEntry("))
        assertFalse(root.contains("resetAssistantTaskFlow("))
        assertFalse(root.contains("applyAssistantDeveloperDataMode("))

        assertTrue(action.contains("openAssistantSingleFlowEntry("))
        assertTrue(action.contains("resetAssistantTaskFlow("))
        assertTrue(action.contains("pauseAssistantTaskFlowAndReturnToPreviousTab("))
        assertTrue(action.contains("returnAssistantResultToHome("))
        assertTrue(action.contains("applyAssistantDeveloperDataMode("))
        assertTrue(pageHostSecondaryFactory.contains("state.taskFlowActions::applyDeveloperDataMode"))
        assertTrue(pageHostAssistantFactory.contains("onStopTask = actions.taskFlow::resetTaskFlow"))
        assertTrue(action.lines().size <= 300)
    }

    @Test
    fun openSingleFlowDelegatesAndConfiguresEntryState() {
        val harness = Harness()

        val handled = harness.actions.openSingleFlow(initialCommand = "  hello  ", startWithVoice = true)

        assertTrue(handled)
        assertEquals("hello", harness.taskEntry.singleFlowInitialCommand)
        assertTrue(harness.taskEntry.singleFlowStartInVoice)
        assertFalse(harness.taskEntry.singleFlowResumeListeningOnly)
        assertEquals(1L, harness.taskEntry.singleFlowEntryKey)
        assertEquals(listOf("reset", "clear", "openSingleFlow"), harness.events)
    }

    @Test
    fun resetAndPauseUseLatestPreviousTabProvider() {
        val harness = Harness()
        harness.previousMainTab = FinalMainTab.Tasks

        harness.actions.resetTaskFlow()

        assertEquals(
            listOf("interrupt:reset_task_flow", "clear", "restore", "close", "refresh", "load"),
            harness.events
        )

        harness.events.clear()
        harness.actions.pauseTaskFlowAndReturnToPreviousTab(source = "single_flow")

        assertEquals(
            listOf(
                "defer:single_flow",
                "pause:close:id-single_flow:false",
                "clear",
                "main:Tasks:Tasks",
                "close",
                "schedule:id-single_flow"
            ),
            harness.events
        )
    }

    @Test
    fun developerDataModeReadsProvidersAtCallTime() {
        val harness = Harness()
        harness.activeAccountId = "old"
        harness.contactsPermissionGranted = false
        harness.currentPage = FinalPage.Home

        harness.activeAccountId = "new-account"
        harness.contactsPermissionGranted = true
        harness.currentPage = FinalPage.Calls
        harness.actions.applyDeveloperDataMode(DeveloperDataMode.Filled)

        assertEquals(
            listOf(
                "developer:Filled",
                "clearCalls:new-account",
                "refresh",
                "contactDeveloper:Filled:true:Calls"
            ),
            harness.events
        )
    }

    private class Harness {
        val events = mutableListOf<String>()
        val taskEntry = taskEntryState()
        var previousMainTab = FinalMainTab.Home
        var currentPage = FinalPage.Assistant
        var activeAccountId = "account"
        var contactsPermissionGranted = false

        val actions = AssistantRootTaskFlowActions(
            AssistantRootTaskFlowActionDeps(
                taskEntry = taskEntry,
                previousMainTabProvider = { previousMainTab },
                currentPageProvider = { currentPage },
                activeAccountIdProvider = { activeAccountId },
                contactsPermissionGrantedProvider = { contactsPermissionGranted },
                shouldBlockOpenSingleFlow = { false },
                shouldBlockResumeSingleFlow = { false },
                onResetTaskConversationForNewEntry = { events += "reset" },
                onClearLocalTaskItemsForRequirementEntry = {
                    events += "clear"
                    taskEntry.clearLocalTaskItemsForRequirementEntry()
                },
                onOpenSingleFlowPage = { events += "openSingleFlow" },
                onResumeSingleFlowPage = { events += "resumeSingleFlow" },
                onOpenAssistantPage = { events += "openAssistant" },
                onShowHomeComposer = { events += "showComposer" },
                onSubmitTextTask = { events += "submit:$it" },
                onStartNewTextTask = { events += "start:$it" },
                onInterruptTaskConversationForUserClose = { events += "interrupt:$it" },
                onRestorePreviousMainTab = { events += "restore" },
                onCloseHomeComposer = { events += "close" },
                onRefreshTasks = { events += "refresh" },
                onLoadConversations = { events += "load" },
                nextDeferredRefreshId = {
                    events += "defer:$it"
                    "id-$it"
                },
                onPauseTaskConversationAndResetLocalUi = { reason, reload ->
                    events += "pause:$reason:$reload"
                },
                onApplyMainTab = { tab, page -> events += "main:$tab:$page" },
                onScheduleTaskRefreshAfterClose = { events += "schedule:$it" },
                onReturnToHomeFromResultPage = { events += "resultReturn" },
                onGoHome = { events += "home" },
                onApplyDeveloperDataMode = { events += "developer:$it" },
                onClearCallRecordsForAccount = { events += "clearCalls:$it" },
                onApplyContactDeveloperDataMode = { mode, granted, page ->
                    events += "contactDeveloper:$mode:$granted:$page"
                }
            )
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }

        fun taskEntryState(): AssistantTaskEntryState = AssistantTaskEntryState(
            taskStarted = mutableStateOf(false),
            taskUserText = mutableStateOf(""),
            taskTextDraft = mutableStateOf(""),
            aiThinking = mutableStateOf(false),
            aiReplyVisible = mutableStateOf(false),
            singleFlowInitialCommand = mutableStateOf(""),
            singleFlowSelectedContact = mutableStateOf(null),
            singleFlowStartInVoice = mutableStateOf(false),
            singleFlowResumeListeningOnly = mutableStateOf(false),
            singleFlowForceNewVoiceEntryStart = mutableStateOf(false),
            singleFlowEntryKey = mutableStateOf(0L),
            pendingVoiceEntryInitialCommand = mutableStateOf(""),
            pendingVoiceEntryStartInVoice = mutableStateOf(true),
            pendingVoiceEntryResumeExisting = mutableStateOf(false),
            pendingVoiceEntryActive = mutableStateOf(false),
            pendingVoiceEntryAccountId = mutableStateOf(""),
            pendingVoiceInteractionPermissionActive = mutableStateOf(false),
            pendingVoiceInteractionAccountId = mutableStateOf(""),
            pendingVoiceInteractionForceNewTaskEntry = mutableStateOf(false),
            pendingVoiceInteractionUseToggle = mutableStateOf(false),
            voiceEntryPermissionGrantedSignal = mutableStateOf(0L),
            selectedRestaurantId = mutableStateOf(null),
            restaurantConfirmed = mutableStateOf(false),
            confirmingRestaurantId = mutableStateOf(null),
            selectedFallbackIds = mutableStateListOf(),
            requiredFallbackIds = mutableStateListOf(),
            fallbackConfirmed = mutableStateOf(false),
            confirmingFallbackId = mutableStateOf(null),
            confirmAttachmentUploaded = mutableStateOf(false),
            aiCallSeconds = mutableStateOf(0)
        )
    }
}
