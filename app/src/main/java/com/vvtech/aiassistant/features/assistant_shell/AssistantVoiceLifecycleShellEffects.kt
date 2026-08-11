package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.*

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.FinalVoiceCloneResourceCleanupEffect
import com.vvtech.aiassistant.features.assistant.FinalVoiceLanguageEffect
import com.vvtech.aiassistant.features.assistant.VoiceLanguage

internal data class AssistantVoiceLifecycleShellEffectsArgs(
    val voiceLanguage: VoiceLanguage,
    val assistantViewModel: AssistantViewModel,
    val onDisposeVoiceCloneRuntime: () -> Unit
)

@Composable
internal fun AssistantVoiceLifecycleShellEffects(args: AssistantVoiceLifecycleShellEffectsArgs) {
    FinalVoiceLanguageEffect(
        voiceLanguage = args.voiceLanguage,
        assistantViewModel = args.assistantViewModel
    )
    FinalVoiceCloneResourceCleanupEffect(
        onDisposeVoiceCloneRuntime = args.onDisposeVoiceCloneRuntime
    )
}
