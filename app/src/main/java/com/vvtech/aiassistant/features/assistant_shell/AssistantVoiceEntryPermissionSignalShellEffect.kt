package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant.FinalVoiceEntryPermissionSignalEffect
import com.vvtech.aiassistant.features.assistant.FinalVoiceEntryPermissionSignalEffectArgs

internal data class AssistantVoiceEntryPermissionSignalShellEffectArgs(
    val voiceEntryPermissionGrantedSignal: Long,
    val hasValidPendingVoiceEntry: (String) -> Boolean,
    val onContinueVoiceEntryAfterMicrophoneGranted: () -> Unit,
    val onVoiceEntryPermissionGrantedSignalReset: () -> Unit
)

@Composable
internal fun AssistantVoiceEntryPermissionSignalShellEffect(
    args: AssistantVoiceEntryPermissionSignalShellEffectArgs
) {
    FinalVoiceEntryPermissionSignalEffect(
        FinalVoiceEntryPermissionSignalEffectArgs(
            voiceEntryPermissionGrantedSignal = args.voiceEntryPermissionGrantedSignal,
            hasValidPendingVoiceEntry = args.hasValidPendingVoiceEntry,
            onContinueVoiceEntryAfterMicrophoneGranted = args.onContinueVoiceEntryAfterMicrophoneGranted,
            onVoiceEntryPermissionGrantedSignalReset = args.onVoiceEntryPermissionGrantedSignalReset
        )
    )
}
