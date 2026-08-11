package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAgentAskQuestionsSheetBoundaryGuardTest {
    @Test
    fun legacyAskQuestionsSheetDelegatesToSessionBoundary() {
        val legacy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AgentAskQuestionsSheet.kt"
        ).readText(Charsets.UTF_8)
        val sheet = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantAgentAskQuestionsSheet.kt"
        ).readText(Charsets.UTF_8)
        val dateTimeFields = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantAgentQuestionDateTimeFields.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(legacy.contains("AssistantAgentAskQuestionsSheet("))
        assertFalse(legacy.contains("mutableStateMapOf"))
        assertFalse(legacy.contains("QuestionBlock"))
        assertFalse(legacy.contains("DatePickerDialog"))
        assertFalse(legacy.contains("TimePickerDialog"))
        assertFalse(legacy.contains("OutlinedTextField"))

        assertTrue(sheet.contains("mutableStateMapOf<String, Any>()"))
        assertTrue(sheet.contains("AgentQuestionBlock("))
        assertTrue(sheet.contains("AgentTextInputField("))
        assertTrue(dateTimeFields.contains("DatePickerDialog("))
        assertTrue(dateTimeFields.contains("TimePickerDialog("))
        assertTrue(dateTimeFields.contains("AgentConfirmField("))

        assertTrue(legacy.lines().size <= 80)
        assertTrue(sheet.lines().size <= 300)
        assertTrue(dateTimeFields.lines().size <= 300)
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
