package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelDelegateFacadeGuardTest {
    @Test
    fun viewModelMainFileDoesNotOwnBulkDelegateFacades() {
        val viewModel = source("AssistantViewModel.kt")
        val taskSessionFacade = facadeSource("AssistantViewModelTaskSessionFacades.kt")
        val voiceCallFacade = facadeSource("AssistantViewModelVoiceCallFacades.kt")
        val agentFacade = facadeSource("AssistantViewModelAgentFacades.kt")

        assertTrue(viewModel.lines().size < 500)
        assertTrue(taskSessionFacade.lines().size <= 300)
        assertTrue(voiceCallFacade.lines().size <= 300)
        assertTrue(agentFacade.lines().size <= 300)

        listOf(
            "fun submitTextTask(rawText: String)",
            "fun onMicClick()",
            "fun refreshCallSessionStatus()",
            "fun onAgentPermissionResult(",
            "fun resetTaskConversationForNewEntry("
        ).forEach { token ->
            assertFalse("ViewModel main file should not own facade: $token", viewModel.contains(token))
        }

        assertTrue(taskSessionFacade.contains("fun AssistantViewModel.submitTextTask(rawText: String)"))
        assertTrue(voiceCallFacade.contains("fun AssistantViewModel.onMicClick()"))
        assertTrue(voiceCallFacade.contains("fun AssistantViewModel.refreshCallSessionStatus()"))
        assertTrue(agentFacade.contains("fun AssistantViewModel.onAgentPermissionResult("))
    }

    private fun source(fileName: String): String {
        return File("src/main/java/com/vvtech/aiassistant/features/assistant/$fileName").readText()
    }

    private fun facadeSource(fileName: String): String {
        return File("src/main/java/com/vvtech/aiassistant/features/assistant_facade/$fileName").readText()
    }
}
