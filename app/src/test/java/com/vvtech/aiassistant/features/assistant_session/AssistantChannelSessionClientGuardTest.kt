package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantChannelSessionClientGuardTest {
    @Test
    fun viewModelDelegatesChannelSessionWorkToClient() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()
        val facade = File("src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelTaskSessionFacades.kt")
            .readText()
        val client = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantChannelSessionClient.kt")
            .readText()

        assertFalse(viewModel.contains("channelSessionClient.ensureTextSession()"))
        assertTrue(facade.contains("channelSessionClient.ensureTextSession()"))
        assertTrue(facade.contains("channelSessionClient.sendActionThroughActiveChannel(actionId, actionLabel)"))
        assertTrue(facade.contains("channelSessionClient.sendDetailSupplementPayload(syncPayload, fallbackTaskId)"))
        assertTrue(facade.contains("channelSessionClient.resolveContactPayload(message)"))

        assertFalse("ViewModel must not build TextTurnRequest directly.", viewModel.contains("TextTurnRequest("))
        assertFalse("ViewModel must not build AssistantMessageRequest directly.", viewModel.contains("AssistantMessageRequest("))
        assertFalse("ViewModel must not resolve device contacts directly.", viewModel.contains("DeviceContactResolver("))

        assertTrue(client.contains("AssistantSessionTurnUseCase(viewModel.repository)"))
        assertTrue(client.contains("sessionTurnUseCase.startTextSession("))
        assertTrue(client.contains("sessionTurnUseCase.sendTextTurn("))
        assertTrue(client.contains("sessionTurnUseCase.sendVoiceMessage("))
        assertFalse("Channel client must not build TextSessionStartRequest directly.", client.contains("TextSessionStartRequest("))
        assertFalse("Channel client must not build TextTurnRequest directly.", client.contains("TextTurnRequest("))
        assertFalse("Channel client must not build AssistantMessageRequest directly.", client.contains("AssistantMessageRequest("))
        assertTrue(client.contains("DeviceContactResolver("))
        assertTrue(client.contains("ContactResolutionPayload("))
    }

    @Test
    fun sessionTurnRequestsStayInUseCase() {
        val useCase = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionTurnUseCase.kt")
            .readText()
        val client = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantChannelSessionClient.kt")
            .readText()
        val submitter = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/ConversationRecognizedTurnSubmitter.kt")
            .readText()
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()

        assertTrue(useCase.contains("class AssistantSessionTurnUseCase"))
        assertTrue(useCase.contains("TextSessionStartRequest("))
        assertTrue(useCase.contains("TextTurnRequest("))
        assertTrue(useCase.contains("AssistantMessageRequest("))
        assertTrue(useCase.lineSequence().count() < 300)

        listOf(
            "AssistantChannelSessionClient" to client,
            "ConversationRecognizedTurnSubmitter" to submitter,
            "AssistantViewModel" to viewModel
        ).forEach { (name, source) ->
            assertFalse("$name must not build TextSessionStartRequest directly.", source.contains("TextSessionStartRequest("))
            assertFalse("$name must not build TextTurnRequest directly.", source.contains("TextTurnRequest("))
            assertFalse("$name must not build AssistantMessageRequest directly.", source.contains("AssistantMessageRequest("))
        }

        assertTrue(submitter.contains("AssistantSessionTurnUseCase(viewModel.repository)"))
        assertTrue(submitter.contains("sessionTurnUseCase.sendVoiceMessage("))
    }
}
