package com.vvtech.aiassistant.features.assistant_pure_voice.input

import com.vvtech.aiassistant.features.assistant.SfInputMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceInputDockStateMachineTest {

    @Test
    fun voiceToTextRequestsExternalModeWithoutChangingMeasurementState() {
        val initial = PureVoiceInputDockMachineState(SfInputMode.Voice, imeVisible = false)
        val result = reducePureVoiceInputDock(
            initial,
            PureVoiceInputDockAction.ModeRequested(SfInputMode.Text)
        )

        assertEquals(PureVoiceInputDockPhase.VoiceResting, result.state.phase)
        assertEquals(
            listOf(PureVoiceInputDockEffect.ChangeMode(SfInputMode.Text)),
            result.effects
        )
    }

    @Test
    fun textWithoutImeSwitchesToVoiceImmediately() {
        val initial = PureVoiceInputDockMachineState(SfInputMode.Text, imeVisible = false)
        val result = reducePureVoiceInputDock(
            initial,
            PureVoiceInputDockAction.ModeRequested(SfInputMode.Voice)
        )

        assertEquals(
            listOf(PureVoiceInputDockEffect.ChangeMode(SfInputMode.Voice)),
            result.effects
        )
        assertFalse(result.state.closingImeForVoice)
    }

    @Test
    fun textWithImeHidesKeyboardThenChangesModeAfterSettlement() {
        val initial = PureVoiceInputDockMachineState(SfInputMode.Text, imeVisible = true)
        val requested = reducePureVoiceInputDock(
            initial,
            PureVoiceInputDockAction.ModeRequested(SfInputMode.Voice)
        )
        assertEquals(listOf(PureVoiceInputDockEffect.HideIme), requested.effects)
        assertTrue(requested.state.closingImeForVoice)
        assertEquals(SfInputMode.Text, requested.state.renderedMode)

        val hidden = reducePureVoiceInputDock(
            requested.state,
            PureVoiceInputDockAction.ImeVisibilityChanged(false)
        )
        assertTrue(hidden.effects.isEmpty())
        assertEquals(PureVoiceInputDockPhase.TextClosingImeForVoice, hidden.state.phase)

        val settled = reducePureVoiceInputDock(
            hidden.state,
            PureVoiceInputDockAction.ClosingPlacementSettled
        )
        assertEquals(
            listOf(PureVoiceInputDockEffect.ChangeMode(SfInputMode.Voice)),
            settled.effects
        )

        val external = reducePureVoiceInputDock(
            settled.state,
            PureVoiceInputDockAction.ExternalModeChanged(SfInputMode.Voice)
        )
        assertEquals(PureVoiceInputDockPhase.VoiceResting, external.state.phase)
        assertFalse(external.state.closingImeForVoice)
    }

    @Test
    fun backHidesImeButKeepsTextMode() {
        val initial = PureVoiceInputDockMachineState(SfInputMode.Text, imeVisible = true)
        val result = reducePureVoiceInputDock(
            initial,
            PureVoiceInputDockAction.ImeVisibilityChanged(false)
        )

        assertEquals(PureVoiceInputDockPhase.TextResting, result.state.phase)
        assertEquals(SfInputMode.Text, result.state.inputMode)
        assertTrue(result.effects.isEmpty())
    }

    @Test
    fun repeatedVoiceRequestWhileClosingDoesNotDuplicateEffects() {
        val closing = PureVoiceInputDockMachineState(
            inputMode = SfInputMode.Text,
            imeVisible = true,
            closingImeForVoice = true
        )
        val result = reducePureVoiceInputDock(
            closing,
            PureVoiceInputDockAction.ModeRequested(SfInputMode.Voice)
        )

        assertTrue(result.effects.isEmpty())
    }
}
