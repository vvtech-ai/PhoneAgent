package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class FinalHomeComponentsGuardTest {
    @Test
    fun finalHomeThreadRendersRestoredCallResultSteps() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalHomeComponents.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(source.contains("step.callResult?.let"))
        assertTrue(source.contains("AgentCallResultCard(result = result)"))
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
