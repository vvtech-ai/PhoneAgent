package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoiceLifecycleShellEffectsTest {
    @Test
    fun rootDelegatesVoiceLifecycleEffectsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantVoiceLifecycleShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPrimaryShellEffects("))
        assertFalse(root.contains("AssistantVoiceLifecycleShellEffects("))
        assertFalse(root.contains("AssistantVoiceLifecycleShellEffectsArgs("))
        assertTrue(primaryShell.contains("AssistantVoiceLifecycleShellEffects("))
        assertTrue(primaryShell.contains("AssistantVoiceLifecycleShellEffectsArgs("))
        assertTrue(primaryShell.contains("voiceLanguage = state.rootSettings.voiceLanguage"))
        assertTrue(primaryShell.contains("assistantViewModel = assistantViewModel"))
        assertTrue(primaryShell.contains("onDisposeVoiceCloneRuntime = runtime.voiceClone::disposeResources"))
        assertFalse(root.contains("FinalVoiceLanguageEffect("))
        assertFalse(root.contains("FinalVoiceCloneResourceCleanupEffect("))

        val voiceLifecycleIndex = primaryShell.indexOf("AssistantVoiceLifecycleShellEffects(")
        val pageLifecycleIndex = primaryShell.indexOf("AssistantPageLifecycleShellEffects(")
        val authCodeRetryIndex = primaryShell.indexOf("AssistantAuthCodeRetryShellEffect(")
        assertTrue(voiceLifecycleIndex >= 0)
        assertTrue(pageLifecycleIndex > voiceLifecycleIndex)
        assertTrue(authCodeRetryIndex > pageLifecycleIndex)

        assertTrue(shell.contains("class AssistantVoiceLifecycleShellEffectsArgs"))
        assertTrue(shell.contains("fun AssistantVoiceLifecycleShellEffects"))
        assertTrue(shell.contains("FinalVoiceLanguageEffect("))
        assertTrue(shell.contains("voiceLanguage = args.voiceLanguage"))
        assertTrue(shell.contains("assistantViewModel = args.assistantViewModel"))
        assertTrue(shell.contains("FinalVoiceCloneResourceCleanupEffect("))
        assertTrue(shell.contains("onDisposeVoiceCloneRuntime = args.onDisposeVoiceCloneRuntime"))
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
