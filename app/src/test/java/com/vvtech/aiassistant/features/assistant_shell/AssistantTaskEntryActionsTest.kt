package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTaskEntryActionsTest {
    @Test
    fun openSingleFlowConfiguresEntryStateAndNavigates() {
        val state = state()
        val recorder = Recorder()

        val handled = openAssistantSingleFlowEntry(
            state = state,
            initialCommand = "  hello  ",
            startWithVoice = true,
            callbacks = recorder.callbacks(state)
        )

        assertTrue(handled)
        assertEquals(1, recorder.resetCount)
        assertEquals(1, recorder.clearCount)
        assertEquals("hello", state.singleFlowInitialCommand)
        assertTrue(state.singleFlowStartInVoice)
        assertFalse(state.singleFlowResumeListeningOnly)
        assertFalse(state.singleFlowForceNewVoiceEntryStart)
        assertEquals(1L, state.singleFlowEntryKey)
        assertEquals(1, recorder.openSingleFlowCount)
    }

    @Test
    fun contactSingleFlowContextIsConsumedOnceWithoutChangingVisibleSeed() {
        val state = state()
        val recorder = Recorder()
        val selectedContact = SelectedContactTaskContext.contactDetail(
            name = "张三",
            phone = "13800138000"
        )

        val handled = openAssistantSingleFlowEntry(
            state = state,
            initialCommand = "请帮我联系 张三",
            selectedContact = selectedContact,
            callbacks = recorder.callbacks(state)
        )

        assertTrue(handled)
        assertEquals("请帮我联系 张三", state.singleFlowInitialCommand)
        assertEquals(selectedContact, state.consumeSingleFlowSelectedContact())
        assertEquals(null, state.consumeSingleFlowSelectedContact())
    }

    @Test
    fun genericSingleFlowEntryClearsPreviousContactContext() {
        val state = state()
        val recorder = Recorder()
        state.singleFlowSelectedContact = SelectedContactTaskContext.contactDetail(
            name = "张三",
            phone = "13800138000"
        )

        openAssistantSingleFlowEntry(
            state = state,
            initialCommand = "查询天气",
            callbacks = recorder.callbacks(state)
        )

        assertEquals(null, state.consumeSingleFlowSelectedContact())
    }

    @Test
    fun openSingleFlowBlocksBeforeMutatingState() {
        val state = state()
        val recorder = Recorder(blockOpen = true)

        val handled = openAssistantSingleFlowEntry(
            state = state,
            initialCommand = "hello",
            startWithVoice = true,
            callbacks = recorder.callbacks(state)
        )

        assertFalse(handled)
        assertEquals(0, recorder.resetCount)
        assertEquals("", state.singleFlowInitialCommand)
        assertEquals(0L, state.singleFlowEntryKey)
    }

    @Test
    fun resumeSingleFlowKeepsResumeListeningSemantics() {
        val state = state()
        state.singleFlowInitialCommand = "old"
        state.singleFlowForceNewVoiceEntryStart = true
        val recorder = Recorder()

        val handled = resumeAssistantSingleFlowEntry(
            state = state,
            startListening = true,
            callbacks = recorder.callbacks(state)
        )

        assertTrue(handled)
        assertEquals("", state.singleFlowInitialCommand)
        assertTrue(state.singleFlowStartInVoice)
        assertTrue(state.singleFlowResumeListeningOnly)
        assertFalse(state.singleFlowForceNewVoiceEntryStart)
        assertEquals(1L, state.singleFlowEntryKey)
        assertEquals(1, recorder.resumeSingleFlowCount)
    }

    @Test
    fun restartSingleFlowResetsAndBumpsEntry() {
        val state = state()
        state.singleFlowEntryKey = 4L
        val recorder = Recorder()

        restartAssistantSingleFlowEntry(state, recorder.callbacks(state))

        assertEquals(1, recorder.resetCount)
        assertEquals(1, recorder.clearCount)
        assertEquals(5L, state.singleFlowEntryKey)
    }

    @Test
    fun submitTextTaskStartsNewEntryWhenTaskHasNotStarted() {
        val state = state()
        state.taskStarted = false
        state.taskTextDraft = "  book table  "
        val recorder = Recorder()

        val handled = submitAssistantTextTaskFlow(state, recorder.callbacks(state))

        assertTrue(handled)
        assertEquals(listOf("book table"), recorder.startedTextTasks)
        assertEquals(emptyList<String>(), recorder.submittedTextTasks)
        assertEquals("", state.taskTextDraft)
        assertEquals(0, recorder.openAssistantCount)
    }

    @Test
    fun submitTextTaskContinuesExistingTaskAndClearsSelections() {
        val state = state()
        state.taskStarted = true
        state.taskTextDraft = "  add note  "
        state.aiReplyVisible = true
        state.selectedRestaurantId = "r1"
        state.selectedFallbackIds.add("f1")
        state.confirmAttachmentUploaded = true
        val recorder = Recorder()

        val handled = submitAssistantTextTaskFlow(state, recorder.callbacks(state))

        assertTrue(handled)
        assertEquals(1, recorder.openAssistantCount)
        assertEquals(1, recorder.showComposerCount)
        assertEquals(listOf("add note"), recorder.submittedTextTasks)
        assertEquals("add note", state.taskUserText)
        assertTrue(state.aiThinking)
        assertFalse(state.aiReplyVisible)
        assertEquals("", state.taskTextDraft)
        assertEquals(null, state.selectedRestaurantId)
        assertTrue(state.selectedFallbackIds.isEmpty())
        assertFalse(state.confirmAttachmentUploaded)
    }

    @Test
    fun rootDelegatesTaskEntryActionsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val action =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTaskEntryActions.kt")
                .readText(Charsets.UTF_8)
        val rootTaskFlowAction =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootTaskFlowActions.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)
        val pageHostAssistantFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText(Charsets.UTF_8)
        val pageHostMainFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val rootTaskFlowActions = rootActionGraph.taskFlow"))
        assertFalse(root.contains("AssistantRootTaskFlowActions("))
        assertTrue(actionGraph.contains("AssistantRootTaskFlowActions("))
        assertTrue(root.contains("taskFlow = rootTaskFlowActions"))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow.openSingleFlow("))
        assertTrue(pageHostMainFactory.contains("actions.taskFlow::restartSingleFlow"))
        assertTrue(pageHostAssistantFactory.contains("onSendText = actions.taskFlow::submitTextTaskFlow"))
        assertFalse(root.contains("AssistantTaskEntryActionCallbacks("))
        assertFalse(root.contains("openAssistantSingleFlowEntry("))
        assertFalse(root.contains("restartAssistantSingleFlowEntry("))
        assertFalse(root.contains("resumeAssistantSingleFlowEntry("))
        assertFalse(root.contains("submitAssistantTextTaskFlow("))
        assertTrue(rootTaskFlowAction.contains("AssistantTaskEntryActionCallbacks("))
        assertTrue(rootTaskFlowAction.contains("openAssistantSingleFlowEntry("))
        assertTrue(rootTaskFlowAction.contains("restartAssistantSingleFlowEntry("))
        assertTrue(rootTaskFlowAction.contains("resumeAssistantSingleFlowEntry("))
        assertTrue(rootTaskFlowAction.contains("submitAssistantTextTaskFlow("))
        assertTrue(action.contains("shouldForceNewTaskVoiceEntryStart("))

        assertFalse(root.contains("val entryCommand = initialCommand?.trim().orEmpty()"))
        assertFalse(root.contains("assistantViewModel.submitTextTask(task)"))
        assertFalse(root.contains("taskEntry.aiReplyVisible = false"))
    }

    private class Recorder(
        private val blockOpen: Boolean = false,
        private val blockResume: Boolean = false
    ) {
        var resetCount = 0
        var clearCount = 0
        var openSingleFlowCount = 0
        var resumeSingleFlowCount = 0
        var openAssistantCount = 0
        var showComposerCount = 0
        val submittedTextTasks = mutableListOf<String>()
        val startedTextTasks = mutableListOf<String>()

        fun callbacks(state: AssistantTaskEntryState) = AssistantTaskEntryActionCallbacks(
            shouldBlockOpenSingleFlow = { blockOpen },
            shouldBlockResumeSingleFlow = { blockResume },
            onResetTaskConversationForNewEntry = { resetCount += 1 },
            onClearLocalTaskItemsForRequirementEntry = {
                clearCount += 1
                state.clearLocalTaskItemsForRequirementEntry()
            },
            onOpenSingleFlowPage = { openSingleFlowCount += 1 },
            onResumeSingleFlowPage = { resumeSingleFlowCount += 1 },
            onOpenAssistantPage = { openAssistantCount += 1 },
            onShowHomeComposer = { showComposerCount += 1 },
            onSubmitTextTask = { submittedTextTasks.add(it) },
            onStartNewTextTask = { startedTextTasks.add(it) }
        )
    }

    private fun state(): AssistantTaskEntryState {
        return AssistantTaskEntryState(
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

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
