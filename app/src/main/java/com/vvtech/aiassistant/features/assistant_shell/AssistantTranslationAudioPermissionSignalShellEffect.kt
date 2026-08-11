package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalTranslationCallAudioPermissionSignalEffect
import com.vvtech.aiassistant.features.assistant.FinalTranslationCallAudioPermissionSignalEffectArgs

internal data class AssistantTranslationAudioPermissionSignalShellEffectArgs(
    val translationCallAudioPermissionGrantedSignal: Long,
    val onStartRealtimeTranslationCallFromDial: () -> Unit
)

@Composable
internal fun AssistantTranslationAudioPermissionSignalShellEffect(
    args: AssistantTranslationAudioPermissionSignalShellEffectArgs
) {
    FinalTranslationCallAudioPermissionSignalEffect(
        FinalTranslationCallAudioPermissionSignalEffectArgs(
            translationCallAudioPermissionGrantedSignal = args.translationCallAudioPermissionGrantedSignal,
            onStartRealtimeTranslationCallFromDial = args.onStartRealtimeTranslationCallFromDial
        )
    )
}
