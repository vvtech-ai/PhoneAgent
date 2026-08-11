package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationSubmitSessionBoundaryGuardTest {
    @Test
    fun conversationSubmitMainFlowLivesInSessionBoundary() {
        val viewModel = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText(Charsets.UTF_8)
        val facade = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelTaskSessionFacades.kt"
        ).readText(Charsets.UTF_8)
        val oldHandler = sourceFileOrNull(
            "src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/ConversationSubmitActionHandler.kt"
        )
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/ConversationSubmitActionHandler.kt"
        ).readText(Charsets.UTF_8)
        val submitter = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/ConversationRecognizedTurnSubmitter.kt"
        ).readText(Charsets.UTF_8)
        val turnUseCase = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionTurnUseCase.kt"
        ).readText(Charsets.UTF_8)

        assertFalse("Old ViewModel-package submit handler must not return.", oldHandler?.exists() == true)
        assertTrue(
            viewModel.contains(
                "import com.vvtech.aiassistant.features.assistant_session.ConversationSubmitActionHandler"
            )
        )
        assertFalse(viewModel.contains("conversationSubmitActionHandler.submitTextTask(rawText)"))
        assertTrue(facade.contains("conversationSubmitActionHandler.submitTextTask(rawText)"))
        assertTrue(facade.contains("conversationSubmitActionHandler.submitRecognizedTurn("))
        assertFalse(viewModel.contains("AssistantMessageRequest("))
        assertFalse(viewModel.contains("repository.sendMessage("))

        assertTrue(handler.contains("class ConversationSubmitActionHandler("))
        assertTrue(handler.contains("private val recognizedTurnSubmitter = ConversationRecognizedTurnSubmitter(viewModel)"))
        assertTrue(handler.contains("recognizedTurnSubmitter.submitRecognizedTurn("))
        assertTrue(handler.contains("SELECTED_CONTACT_CONTEXT_FORWARDED sessionId="))
        assertTrue(handler.contains("hasName=\${selectedContact.name.isNotBlank()}"))
        assertTrue(handler.contains("hasPhone=\${selectedContact.phone.isNotBlank()}"))
        assertFalse(handler.contains("phoneLast4="))
        assertFalse(handler.contains("name=\${selectedContact.name}"))
        assertFalse(handler.contains("AssistantMessageRequest("))
        assertFalse(handler.contains("repository.sendMessage("))

        val clearPendingContact = "conversationSubmitActionHandler.clearSelectedContactForNextTurn()"
        assertTrue(facade.split(clearPendingContact).size - 1 >= 4)
        val backgroundPause = facade
            .substringAfter("fun AssistantViewModel.pauseTaskConversationForBackground()")
            .substringBefore("fun AssistantViewModel.pauseTaskConversationAndResetLocalUi(")
        assertTrue(backgroundPause.contains("taskConversationLifecycleHandler.pauseForBackground()"))
        assertFalse(backgroundPause.contains(clearPendingContact))

        assertTrue(submitter.contains("class ConversationRecognizedTurnSubmitter("))
        assertTrue(submitter.contains("AssistantSessionTurnUseCase(viewModel.repository)"))
        assertTrue(submitter.contains("sessionTurnUseCase.sendVoiceMessage("))
        assertFalse(submitter.contains("AssistantMessageRequest("))
        assertFalse(submitter.contains("repository.sendMessage("))
        assertTrue(turnUseCase.contains("AssistantMessageRequest("))
        assertTrue(turnUseCase.contains("repository.sendMessage("))
        assertTrue(submitter.contains("applySession(response)"))
        assertTrue(submitter.contains("pendingSpeechTurn = speechTurnJob"))
        assertTrue(submitter.contains("drainQueuedRecognizedTurn()"))
        assertTrue(handler.lines().size <= 300)
        assertTrue(submitter.lines().size <= 300)
        assertTrue(viewModel.lines().size < 500)
        assertTrue(facade.lines().size <= 300)
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }

        fun sourceFileOrNull(path: String): File? {
            return listOf(
                File(path),
                File("android/app/$path")
            ).firstOrNull { it.exists() }
        }
    }
}
