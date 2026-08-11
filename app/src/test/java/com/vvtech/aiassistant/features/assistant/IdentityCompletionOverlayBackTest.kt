package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class IdentityCompletionOverlayBackTest {

    @Test
    fun `completion overlay consumes system back and exposes a visible back action`() {
        val source = sourceFile("V61IdentityCompletionOverlay.kt")

        assertTrue(source.contains("BackHandler(enabled = !saving, onBack = onDismiss)"))
        assertTrue(source.contains("contentDescription = \"返回首页\""))
    }

    private fun sourceFile(name: String): String {
        val path = "src/main/java/com/vvtech/aiassistant/features/assistant/$name"
        return listOf(File(path), File("android/app/$path"))
            .first { it.exists() }
            .readText(Charsets.UTF_8)
    }
}
