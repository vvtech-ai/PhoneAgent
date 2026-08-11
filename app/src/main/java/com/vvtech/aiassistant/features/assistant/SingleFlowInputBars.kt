package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowDemoInputPanel as SingleFlowDemoInputPanelContent
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowRealInputBar as SingleFlowRealInputBarContent

@Composable
internal fun BoxScope.SingleFlowRealInputBar(
    assistantState: Index9AssistantUiState?,
    inputMode: SfInputMode = SfInputMode.Text,
    textInput: String,
    bottomOverlayInset: Dp,
    onInputModeChange: (SfInputMode) -> Unit = {},
    onTextInputChange: (String) -> Unit,
    onSubmitText: () -> Unit,
    onVoiceButtonTap: () -> Unit,
    onPauseTtsPlayback: (() -> Unit)?,
    onStopVoiceInteraction: (() -> Unit)?,
    onComposerHeightChanged: (Int) -> Unit
) {
    SingleFlowRealInputBarContent(
        assistantState = assistantState,
        inputMode = inputMode,
        textInput = textInput,
        bottomOverlayInset = bottomOverlayInset,
        onInputModeChange = onInputModeChange,
        onTextInputChange = onTextInputChange,
        onSubmitText = onSubmitText,
        onVoiceButtonTap = onVoiceButtonTap,
        onPauseTtsPlayback = onPauseTtsPlayback,
        onStopVoiceInteraction = onStopVoiceInteraction,
        onComposerHeightChanged = onComposerHeightChanged
    )
}

@Composable
internal fun BoxScope.SingleFlowDemoInputPanel(
    inputMode: SfInputMode,
    textInput: String,
    listening: Boolean,
    bottomOverlayInset: Dp,
    onInputModeChange: (SfInputMode) -> Unit,
    onTextInputChange: (String) -> Unit,
    onSubmitText: () -> Unit,
    onVoiceButtonTap: () -> Unit,
    onStopClick: () -> Unit,
    onComposerHeightChanged: (Int) -> Unit
) {
    SingleFlowDemoInputPanelContent(
        inputMode = inputMode,
        textInput = textInput,
        listening = listening,
        bottomOverlayInset = bottomOverlayInset,
        onInputModeChange = onInputModeChange,
        onTextInputChange = onTextInputChange,
        onSubmitText = onSubmitText,
        onVoiceButtonTap = onVoiceButtonTap,
        onStopClick = onStopClick,
        onComposerHeightChanged = onComposerHeightChanged
    )
}
