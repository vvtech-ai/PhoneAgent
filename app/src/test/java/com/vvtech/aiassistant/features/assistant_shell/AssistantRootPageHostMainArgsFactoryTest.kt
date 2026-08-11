package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootPageHostMainArgsFactoryTest {
    @Test
    fun rootDelegatesMainPageHostArgsAssemblyToFactory() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("buildAssistantRootHostArgs("))
        assertFalse(root.contains("buildAssistantRootPageHostMainArgs("))
        assertFalse(root.contains("AssistantRootPageHostMainArgsFactoryDeps("))
        assertTrue(hostShell.contains("buildAssistantRootPageHostMainArgs("))
        assertTrue(hostShell.contains("AssistantRootPageHostMainArgsFactoryDeps("))
        assertTrue(hostShell.contains("navigation = pageHostMainArgs.navigation"))
        assertTrue(hostShell.contains("contact = pageHostMainArgs.contact"))
        assertTrue(hostShell.contains("call = pageHostMainArgs.call"))
        assertTrue(hostShell.contains("task = pageHostMainArgs.task"))

        mainBuilderInputs.forEach { inputName ->
            assertFalse("$inputName must stay out of AssistantRootScreen", root.contains("$inputName("))
            assertTrue("$inputName must stay in the shell factory", factory.contains("$inputName("))
        }
        assertFalse(root.contains("buildAssistantPageHostNavigationArgs("))
        assertFalse(root.contains("buildAssistantCallArgs("))
        assertFalse(root.contains("buildAssistantTaskPageArgs("))
        assertTrue(factory.contains("buildAssistantPageHostNavigationArgs("))
        assertTrue(factory.contains("runtime.contact.buildArgsInput("))
        assertTrue(factory.contains("buildAssistantCallArgs("))
        assertTrue(factory.contains("buildAssistantTaskPageArgs("))

        assertTrue(factory.contains("actions.taskFlow.openSingleFlow("))
        assertTrue(factory.contains("actions.taskFlow.pauseTaskFlowAndReturnToPreviousTab("))
        assertTrue(factory.contains("actions.taskFlow::restartSingleFlow"))
        assertTrue(factory.contains("actions.taskFlow::goHomePreservingSession"))
        assertTrue(factory.contains("actions.taskFlow.startTaskFlow(it)"))
        assertTrue(factory.contains("actions.callEntry::openDialFromContact"))
        assertTrue(factory.contains("assistantViewModel.hangUpCall"))
        assertTrue(factory.contains("onAiMonitorToggle = assistantViewModel::toggleCallMonitor"))
        assertTrue(factory.contains("onAiAudioRouteSelect = assistantViewModel::selectCallMonitorAudioRoute"))
        assertTrue(factory.contains("onBackResultHome = actions.taskFlow::returnResultToHome"))
        assertTrue(factory.contains("runtime.contactAiModel.modelCallContact(state.pageHost.resultCallId)"))
        assertTrue(factory.contains("runtime.callRecord.appendForAccount(values.activeAccountId, it)"))
        assertTrue(factory.contains("runtime.translation.applyToCallPageArgs(it)"))
        assertTrue(factory.contains("onRefreshRealTasks = { runtime.task.refresh() }"))
        assertTrue(factory.contains("onReturnTaskFromCallDetail = { record ->"))
        assertTrue(factory.contains("val taskId = record.taskId.trim()"))
        assertTrue(factory.contains("assistantViewModel.resumeConversation(taskId)"))
        assertTrue(factory.contains("actions.taskFlow.resumeSingleFlow(startListening = false)"))

        assertTrue(factory.lines().size <= 300)
        assertTrue(root.lines().size < 1100)
        assertTrue(hostShell.lines().size <= 300)
    }

    private companion object {
        val mainBuilderInputs = listOf(
            "AssistantPageHostNavigationInput",
            "AssistantPageHostNavigationState",
            "AssistantPageHostNavigationCallbacks",
            "AssistantContactRuntimeExternalCallbacks",
            "AssistantCallArgsBuilderInput",
            "AssistantCallAiInput",
            "AssistantNormalCallInput",
            "AssistantCallCallbacksInput",
            "AssistantTaskPageArgsBuilderInput"
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
