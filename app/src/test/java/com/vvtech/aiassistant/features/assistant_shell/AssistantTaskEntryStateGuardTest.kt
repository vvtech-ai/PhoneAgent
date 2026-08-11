package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTaskEntryStateGuardTest {
    @Test
    fun rootDelegatesTaskEntryStateToShellHolder() {
        val root = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText()
        val holder = File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTaskEntryState.kt")
            .readText()
        val actionGraph = File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
            .readText()

        assertTrue(root.contains("val taskEntry = rememberAssistantTaskEntryState()"))
        assertFalse(root.contains("taskEntry.clearRequirementSelectionState()"))
        assertFalse(root.contains("taskEntry.clearLocalTaskItemsForRequirementEntry()"))
        assertFalse(root.contains("taskEntry.clearPendingVoiceEntryState"))
        assertTrue(actionGraph.contains("clearAssistantRootLocalTaskItemsForRequirementEntry("))
        assertTrue(actionGraph.contains("taskEntry.clearLocalTaskItemsForRequirementEntry()"))
        assertTrue(actionGraph.contains("clearAssistantRootPendingVoiceEntryState("))
        assertTrue(actionGraph.contains("taskEntry.clearPendingVoiceEntryState"))

        assertFalse(root.contains("var taskStarted by rememberSaveable"))
        assertFalse(root.contains("var singleFlowInitialCommand by rememberSaveable"))
        assertFalse(root.contains("var pendingVoiceEntryActive by remember"))
        assertFalse(root.contains("val selectedFallbackIds = remember"))
        assertFalse(root.contains("var confirmAttachmentUploaded by rememberSaveable"))

        assertTrue(holder.contains("class AssistantTaskEntryState"))
        assertTrue(holder.contains("fun clearRequirementSelectionState()"))
        assertTrue(holder.contains("fun clearLocalTaskItemsForRequirementEntry()"))
        assertTrue(holder.contains("fun clearPendingVoiceEntryState"))
        assertTrue(holder.contains("rememberSaveable { mutableStateOf(false) }"))
        assertTrue(holder.contains("remember { mutableStateListOf<String>() }"))
    }
}
