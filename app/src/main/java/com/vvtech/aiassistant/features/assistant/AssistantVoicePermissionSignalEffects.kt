package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect

internal data class FinalVoiceEntryPermissionSignalEffectArgs(
    val voiceEntryPermissionGrantedSignal: Long,
    val hasValidPendingVoiceEntry: (String) -> Boolean,
    val onContinueVoiceEntryAfterMicrophoneGranted: () -> Unit,
    val onVoiceEntryPermissionGrantedSignalReset: () -> Unit
)

@Composable
internal fun FinalVoiceEntryPermissionSignalEffect(args: FinalVoiceEntryPermissionSignalEffectArgs) {
    LaunchedEffect(args.voiceEntryPermissionGrantedSignal) {
        if (args.voiceEntryPermissionGrantedSignal > 0L) {
            if (args.hasValidPendingVoiceEntry("permission_signal")) {
                args.onContinueVoiceEntryAfterMicrophoneGranted()
            }
            args.onVoiceEntryPermissionGrantedSignalReset()
        }
    }
}

internal data class FinalTranslationCallAudioPermissionSignalEffectArgs(
    val translationCallAudioPermissionGrantedSignal: Long,
    val onStartRealtimeTranslationCallFromDial: () -> Unit
)

@Composable
internal fun FinalTranslationCallAudioPermissionSignalEffect(
    args: FinalTranslationCallAudioPermissionSignalEffectArgs
) {
    LaunchedEffect(args.translationCallAudioPermissionGrantedSignal) {
        if (args.translationCallAudioPermissionGrantedSignal > 0L) {
            args.onStartRealtimeTranslationCallFromDial()
        }
    }
}
