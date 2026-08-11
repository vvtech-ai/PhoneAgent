package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_pure_voice.input.PureVoiceInputDock
import com.vvtech.aiassistant.features.assistant_pure_voice.input.PureVoiceInputDockCallbacks
import com.vvtech.aiassistant.features.assistant_pure_voice.input.PureVoiceInputDockUiState
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrBinding

/** Compatibility bridge for the pure-voice input dock feature. */
@Composable
internal fun PureVoiceInputModePanel(
    inputMode: SfInputMode,
    textInput: String,
    activeCallModelTitle: String,
    onInputModeChange: (SfInputMode) -> Unit,
    onOpenCallModelSheet: () -> Unit,
    onTextInputChange: (String) -> Unit,
    onSubmitText: () -> Unit,
    ocrBinding: PureVoiceOcrBinding,
    bottomControlMode: PureVoiceBottomControlMode,
    voiceLanguage: VoiceLanguage,
    precheckBlocked: Boolean,
    onMicClick: () -> Unit,
    onStop: () -> Unit,
    onMicCancel: () -> Unit,
    onMicTooShort: () -> Unit
) {
    PureVoiceInputDock(
        state = PureVoiceInputDockUiState(
            inputMode = inputMode,
            textInput = textInput,
            activeCallModelTitle = activeCallModelTitle,
            bottomControlMode = bottomControlMode,
            voiceLanguage = voiceLanguage,
            precheckBlocked = precheckBlocked,
            ocrState = ocrBinding.state
        ),
        callbacks = PureVoiceInputDockCallbacks(
            onInputModeChange = onInputModeChange,
            onOpenCallModelSheet = onOpenCallModelSheet,
            onTextInputChange = onTextInputChange,
            onSubmitText = onSubmitText,
            onOcrImageSelected = ocrBinding.callbacks.onImageSelected,
            onMicClick = onMicClick,
            onStop = onStop,
            onMicCancel = onMicCancel,
            onMicTooShort = onMicTooShort
        )
    )
}
