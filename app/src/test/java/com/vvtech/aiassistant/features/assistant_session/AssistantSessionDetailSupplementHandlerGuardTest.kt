package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionDetailSupplementHandlerGuardTest {
    @Test
    fun sessionMapperDelegatesDetailSupplementSideEffects() {
        val mapper = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText(Charsets.UTF_8)
        val graph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        ).readText(Charsets.UTF_8)
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionDetailSupplementHandler.kt"
        ).readText(Charsets.UTF_8)
        val useCase = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionDetailPromptUseCase.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(graph.contains("AssistantSessionDetailPromptUseCase(viewModel.repository)"))
        assertTrue(graph.contains("AssistantSessionDetailSupplementHandler("))
        assertTrue(
            Regex("""AssistantSessionDetailSupplementHandler\(\s*viewModel,\s*detailPromptUseCase\s*\)""")
                .containsMatchIn(graph)
        )
        assertTrue(mapper.contains("deps.handlers.detailSupplementHandler.startFromActionable(session, actionable)"))
        assertTrue(mapper.contains("deps.handlers.detailSupplementHandler.startFromSelection(session, targetName)"))

        assertFalse(mapper.contains("AssistantSessionDetailPromptUseCase(repository)"))
        assertFalse(mapper.contains("AssistantSessionDetailSupplementHandler(viewModel"))
        assertFalse(mapper.contains("loadDetailSupplementPrompts"))
        assertFalse(mapper.contains("DetailSupplementPromptResponse"))
        assertFalse(mapper.contains("DetailSupplementPageData"))
        assertFalse(mapper.contains("DetailSupplementQuestionData"))

        assertTrue(handler.contains("fun startFromActionable"))
        assertTrue(handler.contains("fun startFromSelection"))
        assertFalse(handler.contains("AssistantRepository"))
        assertFalse(handler.contains("repository.loadDetailSupplementPrompts"))
        assertFalse(handler.contains("DetailSupplementPromptResponse("))
        assertTrue(handler.contains("detailPromptUseCase.loadPrompts("))
        assertTrue(useCase.contains("repository.loadDetailSupplementPrompts(sceneType)"))
        assertTrue(useCase.contains("DetailSupplementPromptResponse("))
        assertTrue(handler.contains("state.detailSupplement?.taskId != taskId"))
        assertTrue(handler.contains("state.detailSupplement.copy("))
        assertTrue(handler.contains("localizedPromptResponse(sceneType, promptResponse)"))
    }

    @Test
    fun detailSupplementHandlerKeepsActionableAndSelectionDifferences() {
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionDetailSupplementHandler.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(handler.contains("viewModel.pendingDetailActionable = actionable"))
        assertTrue(handler.contains("viewModel.primarySummaryAction = actionable.primaryAction"))
        assertTrue(handler.contains("viewModel.latestCallPageSeed = actionable.callPageSeed"))
        assertTrue(handler.contains("viewModel.pendingDetailActionable = null"))
        assertTrue(handler.contains("viewModel.primarySummaryAction = null"))
        assertTrue(handler.contains("confirmLabel = DefaultConfirmLabel"))
        assertTrue(handler.lines().size <= 300)
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
