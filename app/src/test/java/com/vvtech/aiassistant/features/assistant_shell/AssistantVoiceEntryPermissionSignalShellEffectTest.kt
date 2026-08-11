package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoiceEntryPermissionSignalShellEffectTest {
    @Test
    fun rootDelegatesVoiceEntryPermissionSignalEffectToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantVoiceEntryPermissionSignalShellEffect.kt"
            ).readText(Charsets.UTF_8)
        val postActionShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPostActionShellEffects.kt"
            ).readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPostActionShellEffects("))
        assertTrue(root.contains("AssistantRootPostActionShellEffectsArgs("))
        assertFalse(root.contains("AssistantVoiceEntryPermissionSignalShellEffect("))
        assertFalse(root.contains("AssistantVoiceEntryPermissionSignalShellEffectArgs("))
        assertTrue(
            postActionShell.contains(
                "voiceEntryPermissionGrantedSignal = taskEntry.voiceEntryPermissionGrantedSignal"
            )
        )
        assertTrue(
            postActionShell.contains("hasValidPendingVoiceEntry = voiceEntryRootActions::hasValidPendingVoiceEntry")
        )
        assertTrue(
            postActionShell.contains("onContinueVoiceEntryAfterMicrophoneGranted =")
        )
        assertTrue(
            postActionShell.contains("voiceEntryRootActions::continueVoiceEntryAfterMicrophoneGranted")
        )
        assertTrue(postActionShell.contains("taskEntry.voiceEntryPermissionGrantedSignal = 0L"))
        assertFalse(root.contains("FinalVoiceEntryPermissionSignalEffect("))
        assertFalse(root.contains("FinalVoiceEntryPermissionSignalEffectArgs("))

        val effectIndex = postActionShell.indexOf("AssistantVoiceEntryPermissionSignalShellEffect(")
        assertTrue(effectIndex >= 0)
        assertTrue(root.contains("val rootNavigationActions = rootActionGraph.navigation"))
        assertFalse(root.contains("AssistantRootNavigationActions("))
        assertTrue(actionGraph.contains("AssistantRootNavigationActions("))
        assertFalse(root.contains("fun switchMainTab("))

        assertTrue(shell.contains("class AssistantVoiceEntryPermissionSignalShellEffectArgs"))
        assertTrue(shell.contains("fun AssistantVoiceEntryPermissionSignalShellEffect"))
        assertTrue(shell.contains("FinalVoiceEntryPermissionSignalEffect("))
        assertTrue(shell.contains("FinalVoiceEntryPermissionSignalEffectArgs("))
        assertTrue(shell.contains("voiceEntryPermissionGrantedSignal = args.voiceEntryPermissionGrantedSignal"))
        assertTrue(shell.contains("hasValidPendingVoiceEntry = args.hasValidPendingVoiceEntry"))
        assertTrue(
            shell.contains(
                "onContinueVoiceEntryAfterMicrophoneGranted = args.onContinueVoiceEntryAfterMicrophoneGranted"
            )
        )
        assertTrue(
            shell.contains(
                "onVoiceEntryPermissionGrantedSignalReset = args.onVoiceEntryPermissionGrantedSignalReset"
            )
        )
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
