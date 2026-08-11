package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CrossBorderTranslationCallUiBoundaryTest {

    @Test
    fun directAndPresetTranslationCallsShareCrossBorderConfirmation() {
        val source = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/" +
                "AssistantCallsDialSheet.kt"
        ).readText()

        assertTrue(source.contains("shouldConfirmCrossBorderTranslationCall("))
        assertTrue(source.contains("CrossBorderTranslationCallDialog("))
        assertEquals(2, Regex("""requestDial\(\)""").findAll(source).count())
    }
}
