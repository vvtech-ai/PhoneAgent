package com.vvtech.aiassistant.features.assistant_agent

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamHandlerBoundaryTest {
    @Test
    fun agentStreamHandlerLivesInAgentBoundary() {
        val newHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt"
        )
        val oldHandlerCandidates = sourceFileCandidates(
            "src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/" + "AgentStreamHandler.kt"
        )

        assertTrue(newHandler.exists())
        assertTrue(newHandler.readText(Charsets.UTF_8).startsWith("package com.vvtech.aiassistant.features.assistant_agent"))
        assertFalse(oldHandlerCandidates.any { it.exists() })
    }

    @Test
    fun viewModelAndGraphImportAgentBoundaryHandler() {
        val viewModel = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        ).readText(Charsets.UTF_8)
        val graph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        ).readText(Charsets.UTF_8)

        val newImport = "import com.vvtech.aiassistant.features.assistant_agent.AgentStreamHandler"
        val oldImport = "import com.vvtech.aiassistant.features.assistant.viewmodel." + "AgentStreamHandler"

        assertTrue(viewModel.contains(newImport))
        assertTrue(graph.contains(newImport))
        assertFalse(viewModel.contains(oldImport))
        assertFalse(graph.contains(oldImport))
        assertTrue(graph.contains("val agentStreamHandler by lazy {"))
        assertTrue(graph.contains("AgentStreamHandler(viewModel, viewModel.repository"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return sourceFileCandidates(path).first { it.exists() }
        }

        fun sourceFileCandidates(path: String): List<File> {
            return listOf(
                File(path),
                File("android/app/$path")
            )
        }
    }
}
