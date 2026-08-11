package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslationAudioPermissionSignalShellEffectTest {
    @Test
    fun rootDelegatesTranslationAudioPermissionSignalEffectToShell() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val shell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTranslationAudioPermissionSignalShellEffect.kt"
            ).readText(Charsets.UTF_8)
        val postActionShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPostActionShellEffects.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("AssistantRootPostActionShellEffects("))
        assertTrue(root.contains("AssistantRootPostActionShellEffectsArgs("))
        assertFalse(root.contains("AssistantTranslationAudioPermissionSignalShellEffect("))
        assertFalse(root.contains("AssistantTranslationAudioPermissionSignalShellEffectArgs("))
        assertTrue(
            postActionShell.contains("translationCallAudioPermissionGrantedSignal =")
        )
        assertTrue(
            postActionShell.contains("runtime.translation.audioPermissionGrantedSignal")
        )
        assertTrue(
            postActionShell.contains("onStartRealtimeTranslationCallFromDial =")
        )
        assertTrue(
            postActionShell.contains("callEntryActions::runDialSheetAction")
        )
        assertFalse(postActionShell.contains("callEntryActions::startRealtimeTranslationCallFromDial"))
        assertFalse(root.contains("FinalTranslationCallAudioPermissionSignalEffect("))
        assertFalse(root.contains("FinalTranslationCallAudioPermissionSignalEffectArgs("))
        assertFalse(Regex("""\bFinal[A-Za-z0-9]+Effect\(""").containsMatchIn(root))

        val voiceIndex = postActionShell.indexOf("AssistantVoiceEntryPermissionSignalShellEffect(")
        val effectIndex = postActionShell.indexOf("AssistantTranslationAudioPermissionSignalShellEffect(")
        val feedbackIndex = postActionShell.indexOf("AssistantTaskEntryFeedbackShellEffects(")
        val pageRuntimeIndex = postActionShell.indexOf("AssistantPageRuntimeShellEffects(")
        assertTrue(voiceIndex >= 0)
        assertTrue(effectIndex > voiceIndex)
        assertTrue(feedbackIndex > effectIndex)
        assertTrue(pageRuntimeIndex > feedbackIndex)
        assertTrue(postActionShell.lines().size <= 140)

        assertTrue(shell.contains("class AssistantTranslationAudioPermissionSignalShellEffectArgs"))
        assertTrue(shell.contains("fun AssistantTranslationAudioPermissionSignalShellEffect"))
        assertTrue(shell.contains("FinalTranslationCallAudioPermissionSignalEffect("))
        assertTrue(shell.contains("FinalTranslationCallAudioPermissionSignalEffectArgs("))
        assertTrue(
            shell.contains(
                "translationCallAudioPermissionGrantedSignal = args.translationCallAudioPermissionGrantedSignal"
            )
        )
        assertTrue(
            shell.contains(
                "onStartRealtimeTranslationCallFromDial = args.onStartRealtimeTranslationCallFromDial"
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
