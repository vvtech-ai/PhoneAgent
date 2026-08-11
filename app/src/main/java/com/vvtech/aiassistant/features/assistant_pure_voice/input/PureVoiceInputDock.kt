package com.vvtech.aiassistant.features.assistant_pure_voice.input

import android.net.Uri
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.updateTransition
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.PureVoiceBottomControlMode
import com.vvtech.aiassistant.features.assistant.SfInputMode
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrUiState
import kotlinx.coroutines.delay

internal data class PureVoiceInputDockUiState(
    val inputMode: SfInputMode,
    val textInput: String,
    val activeCallModelTitle: String,
    val bottomControlMode: PureVoiceBottomControlMode,
    val voiceLanguage: VoiceLanguage,
    val precheckBlocked: Boolean,
    val ocrState: PureVoiceOcrUiState
)

internal data class PureVoiceInputDockCallbacks(
    val onInputModeChange: (SfInputMode) -> Unit,
    val onOpenCallModelSheet: () -> Unit,
    val onTextInputChange: (String) -> Unit,
    val onSubmitText: () -> Unit,
    val onOcrImageSelected: (Uri) -> Unit,
    val onMicClick: () -> Unit,
    val onStop: () -> Unit,
    val onMicCancel: () -> Unit,
    val onMicTooShort: () -> Unit
)

@Composable
@OptIn(ExperimentalLayoutApi::class, ExperimentalComposeUiApi::class)
internal fun PureVoiceInputDock(
    state: PureVoiceInputDockUiState,
    callbacks: PureVoiceInputDockCallbacks
) {
    val imeSnapshot = rememberPureVoiceImeSnapshot()
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val currentCallbacks by rememberUpdatedState(callbacks)
    val attachmentUi = rememberPureVoiceAttachmentUiController(
        state.ocrState.isProcessing,
        currentCallbacks.onOcrImageSelected
    )
    var machine by remember {
        mutableStateOf(
            PureVoiceInputDockMachineState(
                inputMode = state.inputMode,
                imeVisible = imeSnapshot.visible
            )
        )
    }

    fun dispatch(action: PureVoiceInputDockAction) {
        val transition = reducePureVoiceInputDock(machine, action)
        machine = transition.state
        transition.effects.forEach { effect ->
            when (effect) {
                PureVoiceInputDockEffect.HideIme -> {
                    focusManager.clearFocus()
                    keyboardController?.hide()
                }

                is PureVoiceInputDockEffect.ChangeMode -> {
                    currentCallbacks.onInputModeChange(effect.mode)
                }
            }
        }
    }

    LaunchedEffect(state.inputMode) {
        dispatch(PureVoiceInputDockAction.ExternalModeChanged(state.inputMode))
    }
    LaunchedEffect(imeSnapshot.visible) {
        dispatch(PureVoiceInputDockAction.ImeVisibilityChanged(imeSnapshot.visible))
    }
    LaunchedEffect(machine.closingImeForVoice, machine.imeVisible) {
        if (machine.closingImeForVoice && !machine.imeVisible) {
            delay(INPUT_DOCK_ANIMATION_MILLIS.toLong())
            dispatch(PureVoiceInputDockAction.ClosingPlacementSettled)
        }
    }

    val renderedMode = machine.renderedMode
    // Keep the accepted IME control placement while releasing 28dp back to the thread viewport.
    val dockOffset by animateDpAsState(
        targetValue = if (machine.imeVisible) 12.dp else 0.dp,
        animationSpec = tween(INPUT_DOCK_ANIMATION_MILLIS)
    )
    val dockBottomPadding by animateDpAsState(
        targetValue = if (machine.imeVisible) 0.dp else 28.dp,
        animationSpec = tween(INPUT_DOCK_ANIMATION_MILLIS)
    )
    val modeTransition = updateTransition(renderedMode, label = "task_input_mode_shape")
    val textScale by modeTransition.animateFloat(label = "text_input_scale") { mode ->
        if (mode == SfInputMode.Text) 1f else 0.22f
    }
    val voiceScale by modeTransition.animateFloat(label = "voice_input_scale") { mode ->
        if (mode == SfInputMode.Voice) 1f else 0.68f
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .imePadding()
            .offset(y = dockOffset)
            .padding(bottom = dockBottomPadding)
    ) {
        Row(modifier = Modifier.padding(start = 20.dp, bottom = 2.dp)) {
            PureVoiceDockModelSelector(
                title = state.activeCallModelTitle,
                onClick = callbacks.onOpenCallModelSheet
            )
        }
        Box(
            modifier = Modifier.fillMaxWidth().height(88.dp),
            contentAlignment = Alignment.Center
        ) {
            Crossfade(targetState = renderedMode, label = "task_input_mode") { mode ->
                if (mode == SfInputMode.Voice) {
                    Box(modifier = Modifier.graphicsLayer { scaleX = voiceScale; scaleY = voiceScale }) {
                        PureVoiceModeDock(
                            state = state,
                            callbacks = callbacks,
                            onAddClick = attachmentUi.onAddClick,
                            onSwitchToText = {
                                dispatch(PureVoiceInputDockAction.ModeRequested(SfInputMode.Text))
                            }
                        )
                    }
                } else {
                    Box(modifier = Modifier.graphicsLayer { scaleX = textScale; scaleY = textScale }) {
                        PureVoiceTextModeDock(
                            state = state,
                            callbacks = callbacks,
                            onAddClick = attachmentUi.onAddClick,
                            onSwitchToVoice = {
                                dispatch(PureVoiceInputDockAction.ModeRequested(SfInputMode.Voice))
                            }
                        )
                    }
                }
            }
        }
    }
}

private const val INPUT_DOCK_ANIMATION_MILLIS = 180
