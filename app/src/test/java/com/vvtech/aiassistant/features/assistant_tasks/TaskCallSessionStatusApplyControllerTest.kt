package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionStatusApplyControllerTest {
    @Test
    fun callActionHandlerDelegatesStatusApplicationToController() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionStatusApplyController.kt")
                .readText(Charsets.UTF_8)
        val terminalController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionTerminalStatusController.kt")
                .readText(Charsets.UTF_8)
        val factory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionStatusApplyControllerFactory.kt")
                .readText(Charsets.UTF_8)
        val reducer =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskReceiptUiStateReducer.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("TaskCallSessionStatusApplyControllerFactory.create("))
        assertTrue(handler.contains("callSessionStatusApplyController.apply(response, appendNote)"))
        assertTrue(handler.contains("TaskCallSessionTerminalStatusRuntimeActions("))
        assertTrue(handler.contains("viewModel.agentStreamHandler.syncDeferredCallOutcome(callId)"))
        assertTrue(controller.contains("terminalStatusController = deps.terminalStatusController"))
        assertTrue(controller.contains("TaskReceiptUiStateReducer.applyCallSessionNonTerminalDisplay("))
        assertTrue(controller.contains("terminalStatusController.applyDeferredAgentOutcome("))
        assertTrue(controller.contains("terminalStatusController.applyTerminalStatus("))
        assertFalse(controller.contains("TaskCallSessionTerminalStatusController(deps)"))
        assertTrue(factory.contains("TaskCallSessionTerminalStatusController("))
        assertTrue(factory.contains("TaskCallSessionTerminalStatusControllerDeps("))
        assertTrue(factory.contains("terminalStatusController = terminalController"))
        assertFalse(handler.contains("parseTaskCallSessionUpdatedAt("))
        assertFalse(handler.contains("taskCallSessionStatusFacts("))
        assertFalse(handler.contains("shouldDeferTaskCallSessionTerminalStatus("))
        assertFalse(handler.contains("taskCallSessionActiveHistoryPlan("))
        assertFalse(handler.contains("taskCallSessionTerminalHistoryPlan("))
        assertFalse(handler.contains("callSessionTerminalDisplayPlan("))
        assertFalse(handler.contains("protect takeover state from regressive status"))
        assertFalse(handler.contains("defer transport terminal status until reportCallOutcome"))
        assertFalse(handler.contains("TaskReceiptUiStateReducer.applyCallSessionTerminalDisplay"))

        assertTrue(controller.contains("parseTaskCallSessionUpdatedAt("))
        assertTrue(controller.contains("taskCallSessionStatusFacts("))
        assertTrue(controller.contains("shouldDeferTaskCallSessionTerminalStatus("))
        assertFalse(controller.contains("taskCallSessionActiveHistoryPlan("))
        assertTrue(controller.contains("protect takeover state from regressive status"))
        assertFalse(controller.contains("taskCallSessionTerminalHistoryPlan("))
        assertFalse(controller.contains("callSessionTerminalDisplayPlan("))
        assertFalse(controller.contains("defer transport terminal status until reportCallOutcome"))
        assertFalse(controller.contains("private fun applyNonTerminalUiState("))
        assertFalse(controller.contains("callUiMode = if ("))
        assertFalse(controller.contains("handoffInFlight = false"))
        assertFalse(controller.contains("callPageData = state.callPageData.copy("))
        assertFalse(controller.contains("TranscriptRole.Note"))
        assertFalse(controller.contains("TaskReceiptUiStateReducer.applyCallSessionTerminalDisplay"))
        listOf(
            "clearTakeoverProtectWindow",
            "stopCallSessionPolling",
            "resolveLocalCallHistoryStatus",
            "applyCallOutcomePendingDisplay"
        ).forEach { token ->
            assertFalse("apply runtime should not expose terminal-only capability: $token", controller.contains(token))
        }

        assertTrue(reducer.contains("fun applyCallSessionNonTerminalDisplay("))
        assertTrue(reducer.contains("callUiMode = if (facts.humanMode)"))
        assertTrue(reducer.contains("handoffInFlight = false"))
        assertTrue(reducer.contains("callPageData = state.callPageData.copy("))
        assertTrue(reducer.contains("TranscriptLine(TranscriptRole.Note, note)"))
        assertFalse(terminalController.contains("taskCallSessionTerminalHistoryPlan("))
        assertTrue(terminalController.contains("callSessionTerminalDisplayPlan("))
        assertTrue(terminalController.contains("defer transport terminal status until reportCallOutcome"))
        assertTrue(terminalController.contains("TaskReceiptUiStateReducer.applyCallSessionTerminalDisplay"))
        assertTrue(terminalController.contains("TaskCallSessionTerminalStatusControllerDeps"))
        assertTrue(terminalController.contains("TaskCallSessionTerminalStatusRuntimeActions"))
        assertTrue(terminalController.contains("deps.runtime.syncDeferredAgentOutcome(response.callId)"))
        assertFalse(terminalController.contains("TaskCallSessionStatusApplyControllerDeps"))
        assertFalse(terminalController.contains("mergeTranscript"))
        assertFalse(terminalController.contains("ensureTakeoverAudioSocket"))
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
