package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantClarifyChoiceComponentsBoundaryGuardTest {
    @Test
    fun finalClarifyPageDelegatesChoiceComponentsToTaskBoundary() {
        val page = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalClarifyPage.kt"
        ).readText(Charsets.UTF_8)
        val components = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_tasks/AssistantClarifyChoiceComponents.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(page.contains("AssistantClarifyOptionPickerCard("))
        assertTrue(page.contains("AssistantClarifyFallbackBannerCard("))
        assertFalse(page.contains("private fun FinalFallbackBannerCardV3"))
        assertFalse(page.contains("private fun FinalFallbackRequiredSwitch"))
        assertFalse(page.contains("private fun FinalOptionPickerCardV3"))
        assertFalse(page.contains("BorderStroke"))
        assertFalse(page.contains("CircleShape"))
        assertFalse(page.contains("parseInlineMarkdown"))

        assertTrue(components.contains("fun AssistantClarifyFallbackBannerCard("))
        assertTrue(components.contains("fun AssistantClarifyOptionPickerCard("))
        assertTrue(components.contains("fun AssistantClarifyFallbackRequiredSwitch("))
        assertTrue(components.contains("parseInlineMarkdown(title)"))
        assertTrue(components.contains("BorderStroke("))

        assertTrue(page.lines().size <= 300)
        assertTrue(components.lines().size <= 300)
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
