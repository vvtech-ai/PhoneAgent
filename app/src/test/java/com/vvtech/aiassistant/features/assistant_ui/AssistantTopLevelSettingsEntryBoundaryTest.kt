package com.vvtech.aiassistant.features.assistant_ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTopLevelSettingsEntryBoundaryTest {
    @Test
    fun `bottom settings tab is the only top level settings entry`() {
        val bottomBar = source(
            "src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantBottomNavigationBar.kt"
        )
        val topLevelSources = topLevelFiles.joinToString("\n") { source(it) }

        assertTrue(bottomBar.contains("FinalMainTab.Settings"))
        assertFalse(topLevelSources.contains("onOpenSettings"))
        assertFalse(topLevelSources.contains("FinalHomeSettingsButton"))
        assertTrue(topLevelSources.contains("internal fun FinalHomeTopBar()"))
        assertTrue(topLevelSources.contains("internal fun AssistantContactsTopBar()"))
        assertTrue(topLevelSources.contains("internal fun AssistantTasksTopBar()"))
    }

    private fun source(path: String): String = sourceFile(path).readText(Charsets.UTF_8)

    private companion object {
        val topLevelFiles = listOf(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalHomeTopBar.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalHomePage.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalContactsPage.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalCallsListPage.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalTasksPage.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactRows.kt",
            "src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantTaskPageComponents.kt"
        )

        fun sourceFile(path: String): File = listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
