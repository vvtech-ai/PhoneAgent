package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantInitializationTranslationProviderBoundaryTest {
    @Test
    fun `initialization reads and updates the dialer translation preference`() {
        val overlay = source(
            "src/main/java/com/vvtech/aiassistant/features/assistant/V61InitializationOverlay.kt"
        )
        val options = source(
            "src/main/java/com/vvtech/aiassistant/features/assistant/V61InitializationProviderStep.kt"
        )
        val shell = source(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        )

        assertTrue(overlay.contains("initialTranslationProvider: String"))
        assertTrue(overlay.contains("rememberSaveable(initialTranslationProvider)"))
        assertTrue(options.contains("TranslationProviderUiCatalog.allOptions.map"))
        assertTrue(
            shell.contains(
                "initialTranslationProvider = runtime.realtimeTranslation.domesticProviderId"
            )
        )
        assertTrue(
            shell.contains("runtime.realtimeTranslation.selectDomesticProvider(provider)")
        )
        assertTrue(shell.contains("runtime.provider.switchTranslationProvider(provider)"))
    }

    private fun source(path: String): String = sourceFile(path).readText(Charsets.UTF_8)

    private companion object {
        fun sourceFile(path: String): File = listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
