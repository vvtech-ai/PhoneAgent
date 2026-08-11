package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTaskEntryOptionsTest {
    @Test
    fun defaultOptionsKeepExistingFallbackSemantics() {
        val state = deriveAssistantTaskEntryOptions(
            AssistantTaskEntryOptionsInput(
                selectedRestaurantId = null,
                selectedFallbackIds = emptyList()
            )
        )

        assertTrue(state.restaurantOptions.isEmpty())
        assertEquals(2, state.fallbackOptions.size)
        assertEquals("f2", state.fallbackOptions[0].id)
        assertEquals("包间优先", state.fallbackOptions[0].title)
        assertEquals("没有包间则不成立，不接受大厅。", state.fallbackOptions[0].subtitle)
        assertEquals("必须是包间，没有包间就不订。", state.fallbackOptions[0].userLabel)
        assertEquals("f3", state.fallbackOptions[1].id)
        assertEquals("接受相邻时段", state.fallbackOptions[1].title)
        assertEquals("若 19:00 无位，可询问 19:30 或 20:00。", state.fallbackOptions[1].subtitle)
        assertEquals("问是否可以改到 19:30 或 20:00。", state.fallbackOptions[1].userLabel)
    }

    @Test
    fun selectedOptionsAreDerivedFromCurrentIds() {
        val state = deriveAssistantTaskEntryOptions(
            AssistantTaskEntryOptionsInput(
                selectedRestaurantId = "missing",
                selectedFallbackIds = listOf("unknown", "f3", "f2")
            )
        )

        assertNull(state.selectedRestaurant)
        assertEquals(listOf("f2", "f3"), state.selectedFallbacks.map { it.id })
    }

    @Test
    fun rootDelegatesTaskEntryOptionsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val options =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTaskEntryOptions.kt")
                .readText(Charsets.UTF_8)
        val pageHostSecondaryFactory =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostSecondaryArgsFactory.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("deriveAssistantTaskEntryOptions("))
        assertTrue(root.contains("AssistantTaskEntryOptionsInput("))
        assertTrue(root.contains("taskEntryOptions = taskEntryOptions"))
        assertTrue(pageHostSecondaryFactory.contains("values.taskEntryOptions.restaurantOptions"))
        assertTrue(pageHostSecondaryFactory.contains("values.taskEntryOptions.selectedFallbacks"))
        assertFalse(root.contains("remember { emptyList<FinalOption>() }"))
        assertFalse(root.contains("FinalOption("))
        assertFalse(root.contains("selectedRestaurant = restaurantOptions.firstOrNull"))
        assertFalse(root.contains("selectedFallbacks = fallbackOptions.filter"))
        assertFalse(root.contains("包间优先"))
        assertFalse(root.contains("接受相邻时段"))

        assertTrue(options.contains("FinalOption("))
        assertTrue(options.contains("fun deriveAssistantTaskEntryOptions"))
        assertTrue(options.contains("DefaultFallbackOptions"))
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
