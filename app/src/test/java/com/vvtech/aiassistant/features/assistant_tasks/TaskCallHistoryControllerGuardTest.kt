package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallHistoryControllerGuardTest {
    @Test
    fun timelineProjectionIsTheOnlyDurableCallHistoryIngress() {
        val controller = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallHistoryController.kt"
        ).readText(Charsets.UTF_8)
        val timelineHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamTimelineCommittedHandler.kt"
        ).readText(Charsets.UTF_8)
        val streamHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt"
        ).readText(Charsets.UTF_8)
        val handlerGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(controller.contains("fun acceptTimelineProjection("))
        assertTrue(controller.contains("ConversationTimelineCallHistoryAdapter.adapt(items)"))
        assertTrue(timelineHandler.contains("acceptTimelineProjection(projection.sessionId, projection.timelineItems)"))
        assertTrue(streamHandler.contains("acceptTimelineProjection = viewModel.taskCallHistoryController::acceptTimelineProjection"))
        assertFalse(handlerGraph.contains("TaskCallHistoryStore"))
        assertFalse(handlerGraph.contains("index9_call_history"))

        val productionFiles = sourceFile("src/main/java").walkTopDown().filter(File::isFile).toList()
        listOf(
            "upsertLocalCallHistory",
            "persistLocalCallHistory",
            "loadLocalCallHistoryIntoController",
            "clearLocalCallHistory",
            "call_history_",
            "TaskCallHistoryStore"
        ).forEach { forbidden ->
            assertFalse(
                "production must not retain legacy call-history write/store chain: $forbidden",
                productionFiles.any { it.readText(Charsets.UTF_8).contains(forbidden) }
            )
        }
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
