package com.vvtech.aiassistant.features.assistant_pure_voice.input

import com.vvtech.aiassistant.features.assistant.SfInputMode

internal enum class PureVoiceInputDockPhase {
    VoiceResting,
    TextResting,
    TextWithIme,
    TextClosingImeForVoice
}

internal data class PureVoiceInputDockMachineState(
    val inputMode: SfInputMode,
    val imeVisible: Boolean,
    val closingImeForVoice: Boolean = false
) {
    val phase: PureVoiceInputDockPhase
        get() = when {
            closingImeForVoice -> PureVoiceInputDockPhase.TextClosingImeForVoice
            inputMode == SfInputMode.Voice -> PureVoiceInputDockPhase.VoiceResting
            imeVisible -> PureVoiceInputDockPhase.TextWithIme
            else -> PureVoiceInputDockPhase.TextResting
        }

    val renderedMode: SfInputMode
        get() = if (closingImeForVoice) SfInputMode.Text else inputMode
}

internal sealed interface PureVoiceInputDockAction {
    data class ExternalModeChanged(val mode: SfInputMode) : PureVoiceInputDockAction
    data class ImeVisibilityChanged(val visible: Boolean) : PureVoiceInputDockAction
    data class ModeRequested(val mode: SfInputMode) : PureVoiceInputDockAction
    object ClosingPlacementSettled : PureVoiceInputDockAction
}

internal sealed interface PureVoiceInputDockEffect {
    object HideIme : PureVoiceInputDockEffect
    data class ChangeMode(val mode: SfInputMode) : PureVoiceInputDockEffect
}

internal data class PureVoiceInputDockTransition(
    val state: PureVoiceInputDockMachineState,
    val effects: List<PureVoiceInputDockEffect> = emptyList()
)

internal fun reducePureVoiceInputDock(
    state: PureVoiceInputDockMachineState,
    action: PureVoiceInputDockAction
): PureVoiceInputDockTransition = when (action) {
    is PureVoiceInputDockAction.ExternalModeChanged -> {
        if (action.mode == state.inputMode) {
            PureVoiceInputDockTransition(state)
        } else {
            PureVoiceInputDockTransition(
                state.copy(inputMode = action.mode, closingImeForVoice = false)
            )
        }
    }

    is PureVoiceInputDockAction.ImeVisibilityChanged -> {
        PureVoiceInputDockTransition(state.copy(imeVisible = action.visible))
    }

    is PureVoiceInputDockAction.ModeRequested -> when {
        action.mode == state.inputMode || state.closingImeForVoice -> {
            PureVoiceInputDockTransition(state)
        }

        action.mode == SfInputMode.Text -> {
            PureVoiceInputDockTransition(
                state,
                listOf(PureVoiceInputDockEffect.ChangeMode(SfInputMode.Text))
            )
        }

        state.imeVisible -> {
            PureVoiceInputDockTransition(
                state.copy(closingImeForVoice = true),
                listOf(PureVoiceInputDockEffect.HideIme)
            )
        }

        else -> {
            PureVoiceInputDockTransition(
                state,
                listOf(PureVoiceInputDockEffect.ChangeMode(SfInputMode.Voice))
            )
        }
    }

    PureVoiceInputDockAction.ClosingPlacementSettled -> {
        if (state.closingImeForVoice && !state.imeVisible) {
            PureVoiceInputDockTransition(
                state,
                listOf(PureVoiceInputDockEffect.ChangeMode(SfInputMode.Voice))
            )
        } else {
            PureVoiceInputDockTransition(state)
        }
    }
}
