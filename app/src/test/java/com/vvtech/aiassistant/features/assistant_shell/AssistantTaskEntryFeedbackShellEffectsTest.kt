package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTaskEntryFeedbackShellEffectsTest {
    @Test
    fun rootDelegatesTaskEntryFeedbackEffectsToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTaskEntryFeedbackShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val postActionShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPostActionShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPostActionShellEffects("))
        assertFalse(root.contains("AssistantTaskEntryFeedbackShellEffects("))
        assertFalse(root.contains("AssistantTaskEntryFeedbackShellEffectsArgs("))
        assertFalse(root.contains("AssistantAiThinkingFeedbackEffectArgs("))
        assertFalse(root.contains("AssistantRestaurantConfirmFeedbackEffectArgs("))
        assertFalse(root.contains("AssistantFallbackConfirmFeedbackEffectArgs("))
        assertTrue(postActionShell.contains("AssistantTaskEntryFeedbackShellEffects("))
        assertTrue(postActionShell.contains("AssistantTaskEntryFeedbackShellEffectsArgs("))
        assertTrue(postActionShell.contains("AssistantAiThinkingFeedbackEffectArgs("))
        assertTrue(postActionShell.contains("AssistantRestaurantConfirmFeedbackEffectArgs("))
        assertTrue(postActionShell.contains("AssistantFallbackConfirmFeedbackEffectArgs("))
        assertTrue(postActionShell.contains("aiThinking = taskEntry.aiThinking"))
        assertTrue(postActionShell.contains("confirmingRestaurantId = taskEntry.confirmingRestaurantId"))
        assertTrue(postActionShell.contains("confirmingFallbackId = taskEntry.confirmingFallbackId"))
        assertTrue(postActionShell.contains("onAiReplyVisibleChange = { taskEntry.aiReplyVisible = it }"))
        assertTrue(postActionShell.contains("onConfirmingFallbackIdChange = { taskEntry.confirmingFallbackId = it }"))
        assertFalse(root.contains("FinalAiThinkingEffect("))
        assertFalse(root.contains("FinalAiThinkingEffectArgs("))
        assertFalse(root.contains("FinalRestaurantConfirmEffect("))
        assertFalse(root.contains("FinalRestaurantConfirmEffectArgs("))
        assertFalse(root.contains("FinalFallbackConfirmEffect("))
        assertFalse(root.contains("FinalFallbackConfirmEffectArgs("))

        assertTrue(shell.contains("fun AssistantTaskEntryFeedbackShellEffects"))
        assertTrue(shell.contains("FinalAiThinkingEffect("))
        assertTrue(shell.contains("FinalRestaurantConfirmEffect("))
        assertTrue(shell.contains("FinalFallbackConfirmEffect("))
        assertTrue(shell.contains("FinalAiThinkingEffectArgs("))
        assertTrue(shell.contains("FinalRestaurantConfirmEffectArgs("))
        assertTrue(shell.contains("FinalFallbackConfirmEffectArgs("))
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
