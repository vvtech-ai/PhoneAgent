package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslationRuntimeShellEffectsTest {
    @Test
    fun rootDelegatesTranslationRuntimeEffectsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTranslationRuntimeShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPrimaryShellEffects("))
        assertFalse(root.contains("AssistantTranslationRuntimeShellEffects("))
        assertFalse(root.contains("AssistantTranslationRuntimeShellEffectsArgs("))
        assertTrue(primaryShell.contains("AssistantTranslationRuntimeShellEffects("))
        assertTrue(primaryShell.contains("AssistantTranslationRuntimeShellEffectsArgs("))
        assertTrue(primaryShell.contains("context = context"))
        assertTrue(primaryShell.contains("lifecycleOwner = lifecycleOwner"))
        assertTrue(primaryShell.contains("currentPage = currentPage"))
        assertTrue(primaryShell.contains("runtime = runtime.translation"))
        assertFalse(root.contains("features.assistant_translation.FinalTranslationCallRuntimeEffects"))
        assertFalse(root.contains("FinalTranslationCallRuntimeEffects("))

        assertTrue(shell.contains("data class AssistantTranslationRuntimeShellEffectsArgs("))
        assertTrue(shell.contains("fun AssistantTranslationRuntimeShellEffects("))
        assertTrue(shell.contains("FinalTranslationCallRuntimeEffects("))
        assertTrue(shell.contains("context = args.context"))
        assertTrue(shell.contains("lifecycleOwner = args.lifecycleOwner"))
        assertTrue(shell.contains("currentPage = args.currentPage"))
        assertTrue(shell.contains("runtime = args.runtime"))
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
