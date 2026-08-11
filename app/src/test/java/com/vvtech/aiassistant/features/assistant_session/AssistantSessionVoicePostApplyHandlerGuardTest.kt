package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionVoicePostApplyHandlerGuardTest {
    @Test
    fun sessionMapperDelegatesVoicePostApplySideEffects() {
        assertFalse(
            sourceFileOrNull("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/SessionMapper.kt")
                ?.exists() == true
        )
        val mapper = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText(Charsets.UTF_8)
        val graph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        ).readText(Charsets.UTF_8)
        val voiceApplyHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionVoiceApplyHandler.kt"
        ).readText(Charsets.UTF_8)
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionVoicePostApplyHandler.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(graph.contains("AssistantSessionVoicePostApplyHandler(viewModel)"))
        assertFalse(mapper.contains("AssistantSessionVoicePostApplyHandler(viewModel)"))
        assertTrue(mapper.contains("handleAfterVoiceApply = deps.handlers.voicePostApplyHandler::handleAfterVoiceApply"))
        assertTrue(mapper.contains("deps.handlers.voicePostApplyHandler.scheduleAutoResumeListening(delayMillis)"))
        assertTrue(mapper.contains("deps.handlers.voicePostApplyHandler.estimateAssistantResumeDelay(session)"))
        assertTrue(voiceApplyHandler.contains("deps.actions.handleAfterVoiceApply("))
        assertTrue(voiceApplyHandler.contains("AssistantSessionVoicePostApplyContext("))

        assertFalse(mapper.contains("voicePostApplyHandler.handleAfterVoiceApply("))
        assertFalse(mapper.contains("AssistantSessionVoicePostApplyContext("))
        assertFalse(mapper.contains("viewModel.autoResumeListeningJob"))
        assertFalse(mapper.contains("viewModel.queuedRecognizedTurns"))
        assertFalse(mapper.contains("viewModel.pendingAutoListenAfterSelectionPrompt"))
        assertFalse(mapper.contains("viewModel.viewModelScope.launch"))
        assertFalse(mapper.contains("kotlinx.coroutines.delay"))
        assertFalse(mapper.contains("private fun reconnectingStatus"))

        assertTrue(handler.contains("viewModel.pendingAutoListenAfterSelectionPrompt = context.selectionSheetPresent"))
        assertTrue(handler.contains("viewModel.playBackendAssistantPromptFully(context.newestBackendAssistantPrompt)"))
        assertTrue(handler.contains("viewModel.resumeVoiceSelectionListeningAfterPrompt()"))
        assertTrue(handler.contains("viewModel.autoResumeListeningJob = viewModel.viewModelScope.launch"))
        assertTrue(handler.contains("viewModel.drainQueuedRecognizedTurn()"))
        assertTrue(handler.contains("viewModel.queuedRecognizedTurns.clear()"))
        assertTrue(handler.contains("AssistantSessionDialogueStepPolicy::extractVisibleAssistantDialogueText"))
        assertTrue(handler.contains("state.stage != AssistantStage.Clarifying"))
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
