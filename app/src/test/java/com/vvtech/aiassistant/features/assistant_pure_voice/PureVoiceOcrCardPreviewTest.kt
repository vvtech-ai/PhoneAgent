package com.vvtech.aiassistant.features.assistant_pure_voice

import org.junit.Assert.assertEquals
import org.junit.Test

class PureVoiceOcrCardPreviewTest {

    @Test
    fun fullTextOverFiftyCharactersUsesTheCollapsedPreview() {
        val text = "字".repeat(51)

        assertEquals(true, text.isOcrCardCollapsible())
        assertEquals("字".repeat(50) + "……", text.ocrCardDisplayText(expanded = false))
        assertEquals(text, text.ocrCardDisplayText(expanded = true))
    }

    @Test
    fun exactlyFiftyCharactersDoesNotShowTheToggle() {
        val text = "字".repeat(50)

        assertEquals(false, text.isOcrCardCollapsible())
        assertEquals(text, text.ocrCardDisplayText(expanded = false))
    }
}
