package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionClarificationStepHandlerGuardTest {
    @Test
    fun sessionMapperDelegatesClarificationStepStateMaintenance() {
        val mapper = File("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText()
        val graph = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        ).readText()
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionClarificationStepHandler.kt")
                .readText()

        assertTrue(graph.contains("SessionMapperDeps("))
        assertTrue(graph.contains("AssistantSessionClarificationStepHandler(viewModel)"))
        assertTrue(mapper.contains("private val deps: SessionMapperDeps"))
        assertTrue(mapper.contains("deps.handlers.clarificationStepHandler.appendClarificationStep(role, text)"))
        assertTrue(mapper.contains("deps.handlers.clarificationStepHandler.snapshotVisibleClarificationSteps(state)"))
        assertTrue(mapper.contains("deps.handlers.clarificationStepHandler.commitVisibleAssistantTranscriptIfNeeded()"))

        assertFalse(mapper.contains("AssistantSessionClarificationStepHandler(viewModel)"))
        assertFalse(mapper.contains("AssistantViewModel"))
        assertFalse(mapper.contains("AssistantRepository"))
        assertFalse(mapper.contains("viewModel."))
        assertFalse(mapper.contains("AppFileLogger.logConversation("))
        assertFalse(mapper.contains("appendClarificationStepIfMissing(steps"))
        assertFalse(mapper.contains("lastCommittedAssistantTranscript = normalized"))

        assertTrue(handler.contains("AppFileLogger.logConversation("))
        assertTrue(handler.contains("AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing("))
        assertTrue(handler.contains("VoiceRole.User"))
        assertTrue(handler.contains("VoiceRole.Assistant"))
        assertTrue(handler.contains("lastCommittedAssistantTranscript = normalized"))
    }
}
