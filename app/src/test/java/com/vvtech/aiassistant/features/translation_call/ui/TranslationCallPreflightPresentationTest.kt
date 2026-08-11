package com.vvtech.aiassistant.features.translation_call.ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallPreflightPresentationTest {
    @Test
    fun translationCallOverlayRendersCallScreenWithoutBlockingPreflightDialog() {
        val source = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/" +
                "AssistantOverlayHostSections.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(source.contains("rememberTranslationCallPreflightVisible"))
        assertFalse(source.contains("TranslationCallPreflightDialog()"))
        assertTrue(source.contains("if (translationCallState.visible)"))
        assertTrue(source.contains("TranslationCallScreen("))
    }
}
