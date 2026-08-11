package com.vvtech.aiassistant.features.assistant_actions

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAgentDocumentActionHandlerGuardTest {
    @Test
    fun viewModelDelegatesAgentDocumentImportWork() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()
        val facade = File("src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelAgentFacades.kt")
            .readText()
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_actions/AssistantAgentDocumentActionHandler.kt")
                .readText()
        val useCase =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_actions/AssistantAgentDocumentImportUseCase.kt")
                .readText()

        assertFalse(viewModel.contains("agentDocumentActionHandler.onDocumentPickerCancelled()"))
        assertTrue(facade.contains("agentDocumentActionHandler.onDocumentPickerCancelled()"))
        assertTrue(facade.contains("agentDocumentActionHandler.onDocumentPicked(uri)"))

        assertFalse(viewModel.contains("OpenableColumns"))
        assertFalse(viewModel.contains("parseDocument("))
        assertFalse(viewModel.contains("openInputStream(uri)"))
        assertFalse(viewModel.contains("FILE_TOO_LARGE"))

        assertFalse(handler.contains("OpenableColumns"))
        assertFalse(handler.contains("parseDocument("))
        assertFalse(handler.contains("openInputStream(uri)"))
        assertFalse(handler.contains("FILE_TOO_LARGE"))
        assertFalse(handler.contains("DocumentParseResult("))
        assertTrue(handler.contains("AssistantAgentDocumentImportUseCase("))
        assertTrue(handler.contains("documentImportUseCase.cancelledResult()"))
        assertTrue(handler.contains("documentImportUseCase.parse(uri, request.maxBytes)"))
        assertTrue(handler.contains("onAgentDocumentSubmit(result)"))

        assertTrue(useCase.contains("OpenableColumns"))
        assertTrue(useCase.contains("repository.parseDocument("))
        assertTrue(useCase.contains("openInputStream(uri)"))
        assertTrue(useCase.contains("FILE_TOO_LARGE"))
        assertTrue(useCase.contains("DocumentParseResult("))
        assertTrue(useCase.lines().size <= 300)
    }
}
