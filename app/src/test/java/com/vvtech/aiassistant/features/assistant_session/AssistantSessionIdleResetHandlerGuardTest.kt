package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionIdleResetHandlerGuardTest {
    @Test
    fun sessionMapperDelegatesIdleResetSideEffects() {
        val mapper = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText()
        val graph = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        ).readText()
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionIdleResetHandler.kt")
                .readText()
        val resetEntry = mapper
            .substringAfter("fun resetToIdleHome()")
            .substringBefore("fun resolveActionableSummary")

        assertTrue(graph.contains("AssistantSessionIdleResetHandler(viewModel)"))
        assertTrue(resetEntry.contains("deps.handlers.idleResetHandler.resetToIdleHome()"))
        assertFalse(mapper.contains("AssistantSessionIdleResetHandler(viewModel)"))
        assertFalse(resetEntry.contains("viewModel."))
        assertFalse(resetEntry.contains("CallPageData("))
        assertFalse(resetEntry.contains("DefaultRetryLabel"))
        assertFalse(resetEntry.contains("DefaultIdleExample"))
        assertFalse(resetEntry.contains("CallUiMode.Ai"))

        assertTrue(handler.contains("viewModel.stopCallSessionPolling()"))
        assertTrue(handler.contains("viewModel.stopTakeoverAudioSocket()"))
        assertTrue(handler.contains("viewModel.autoResumeListeningJob?.cancel()"))
        assertTrue(handler.contains("viewModel.queuedRecognizedTurns.clear()"))
        assertTrue(handler.contains("viewModel.activeInteractionChannel = InteractionChannel.NONE"))
        assertTrue(handler.contains("CallPageData("))
        assertTrue(handler.contains("retryLabel = DefaultRetryLabel"))
        assertTrue(handler.contains("exampleText = DefaultIdleExample"))
        assertTrue(handler.contains("callUiMode = CallUiMode.Ai"))
        assertTrue(handler.contains("agentCallResult = null"))
    }
}
