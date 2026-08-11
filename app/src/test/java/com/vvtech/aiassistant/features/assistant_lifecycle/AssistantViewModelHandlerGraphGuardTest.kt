package com.vvtech.aiassistant.features.assistant_lifecycle

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelHandlerGraphGuardTest {
    @Test
    fun handlerGraphOwnsViewModelDelegateWiring() {
        val viewModelFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        )
        val graphFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        )
        val viewModel = viewModelFile.readText(Charsets.UTF_8)
        val graph = graphFile.readText(Charsets.UTF_8)

        assertTrue(viewModelFile.readLines(Charsets.UTF_8).size < 850)
        assertTrue(graphFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(viewModel.contains("private val handlerGraph = AssistantViewModelHandlerGraph(this)"))
        assertTrue(viewModel.contains("get() = handlerGraph.conversationRestoreHandler"))
        assertTrue(viewModel.contains("get() = handlerGraph.localPromptActionHandler"))

        listOf(
            "RestoreHandlerDeps(",
            "TaskErrorRecoveryHolder(",
            "AssistantTaskConversationLifecycleHandler(",
            "TaskCallHistoryController(",
            "LocalPromptActionHandler(",
            "LocalPromptCallbacks("
        ).forEach { constructor ->
            assertFalse("ViewModel should not inline $constructor", viewModel.contains(constructor))
            assertTrue("Handler graph should own $constructor", graph.contains(constructor))
        }

        assertTrue(graph.contains("val agentStreamHandler by lazy"))
        assertTrue(graph.contains("val callActionHandler by lazy"))
        assertTrue(graph.contains("val sessionMapper by lazy"))
        assertTrue(graph.contains("val voiceDuplexCoordinator by lazy"))
        assertTrue(graph.contains("val voiceRuntimeHandler by lazy"))
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
