package com.vvtech.aiassistant.features.assistant_ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantBottomNavigationBackdropTest {

    @Test
    fun `backdrop is a non interactive draw layer synchronized with navigation visibility`() {
        val backdrop = source(
            "main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantBottomNavigationBackdrop.kt"
        )
        val host = source(
            "main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantPageBackdropHost.kt"
        )

        assertTrue(backdrop.contains("RenderEffect.createBlurEffect"))
        assertTrue(backdrop.contains("drawContent()"))
        assertTrue(backdrop.contains("BottomNavigationBackdropHeight"))
        assertFalse(backdrop.contains("clickable("))
        assertFalse(backdrop.contains("pointerInput("))
        assertFalse(backdrop.contains("AndroidView"))
        assertTrue(host.contains("isBottomNavigationHidden()"))
        assertTrue(host.contains("animateFloatAsState"))
    }

    private fun source(relativePath: String): String =
        File("src/$relativePath").readText(Charsets.UTF_8)
}
