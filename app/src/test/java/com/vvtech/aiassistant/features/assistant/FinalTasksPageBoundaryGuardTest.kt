package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FinalTasksPageBoundaryGuardTest {
    @Test
    fun taskPageRowsAndComponentsStayOutOfLegacyPageEntry() {
        val pageFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalTasksPage.kt")
        val componentFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantTaskPageComponents.kt")
        val rowsFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskPageRows.kt")
        val page = pageFile.readText(Charsets.UTF_8)
        val components = componentFile.readText(Charsets.UTF_8)
        val rows = rowsFile.readText(Charsets.UTF_8)

        assertTrue("FinalTasksPage should stay a thin page entry.", pageFile.readLines(Charsets.UTF_8).size <= 180)
        assertTrue("FinalTasksPageComponents must stay below the new-file guard threshold.", componentFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue("TaskPageRows must stay below the new-file guard threshold.", rowsFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Task page entry should delegate row construction to the assistant_tasks boundary.",
            page.contains("import com.vvtech.aiassistant.features.assistant_tasks.buildTaskPageRows") &&
                page.contains("val taskPageRows = buildTaskPageRows(records, conversations)")
        )
        forbiddenPageTokens.forEach { token ->
            assertFalse("Task page implementation detail must not return to FinalTasksPage: $token", page.contains(token))
        }
        assertTrue(
            "Task page UI components should live in the component file.",
                components.contains("internal fun AssistantTaskSyncStatusRow(") &&
                components.contains("internal fun AssistantTaskInitialLoading(") &&
                components.contains("internal fun AssistantTasksTopBar(") &&
                components.contains("internal fun AssistantTaskDesignRow(")
        )
        assertTrue(
            "Task page row construction should live in the assistant_tasks boundary.",
            rows.contains("internal data class TaskPageRow(") &&
                rows.contains("internal fun buildTaskPageRows(") &&
                rows.contains("finalTaskDisplaySortEpochMillis")
        )
        bannedRowDependencies.forEach { dependency ->
            assertFalse("TaskPageRows must not depend on UI/runtime dependency: $dependency", rows.contains(dependency))
        }
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse("Task page components must not depend on runtime/business dependency: $dependency", components.contains(dependency))
        }
    }

    private companion object {
        val forbiddenPageTokens = listOf(
            "private data class FinalTaskPageRow",
            "val completedConversations = conversations",
            "val activeConversations = conversations",
            "buildList {",
            "compareByDescending<FinalTaskPageRow>",
            "private fun FinalTaskSyncStatusRow",
            "private fun FinalTaskInitialLoading",
            "private fun FinalTasksDesignTopBar",
            "private fun FinalTaskDesignRow",
            "private fun finalTaskDesignStatusColor"
        )

        val bannedRowDependencies = listOf(
            "androidx.compose",
            "Repository",
            "AssistantContainer",
            "AppContainer",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "Asr",
            "Tts",
            "SIP",
            "AgentStream"
        )

        val bannedRuntimeDependencies = listOf(
            "Repository",
            "AssistantContainer",
            "AppContainer",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "Asr",
            "Tts",
            "SIP",
            "AgentStream"
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
