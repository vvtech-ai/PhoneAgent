package com.vvtech.aiassistant.features.assistant_voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskVoiceTurnStateMachineTest {

    @Test
    fun manualVoiceTurnRecordsExpectedPhaseSequence() {
        val logs = mutableListOf<String>()
        val stateMachine = TaskVoiceTurnStateMachine(logs::add)

        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        stateMachine.onAsrReady("dialog_asr")
        stateMachine.onAsrFinalBuffered("给我定个北海渔村的包间", "dialog_asr")
        stateMachine.onManualReleaseSubmit("给我定个北海渔村的包间", "bottom_release")
        stateMachine.onTtsPlaybackStarted("agent_signal")
        stateMachine.onTtsPlaybackCompleted("agent_signal")

        assertEquals(TaskVoiceTurnPhase.Idle, stateMachine.snapshot.phase)
        assertEquals(
            listOf(
                "idle->asr_connecting",
                "asr_connecting->asr_listening",
                "asr_listening->awaiting_manual_release",
                "awaiting_manual_release->agent_submitting",
                "agent_submitting->tts_playing",
                "tts_playing->idle"
            ),
            logs.map { line ->
                val before = line.substringAfter("phaseBefore=").substringBefore(" ")
                val after = line.substringAfter("phaseAfter=").substringBefore(" ")
                "$before->$after"
            }
        )
    }

    @Test
    fun finalWhileButtonHeldOnlyMovesToAwaitingManualRelease() {
        val stateMachine = TaskVoiceTurnStateMachine()

        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        stateMachine.onAsrReady("dialog_asr")
        val transition = stateMachine.onAsrFinalBuffered("给小明打电话", "dialog_asr")

        assertEquals(TaskVoiceTurnPhase.AsrListening, transition.before.phase)
        assertEquals(TaskVoiceTurnPhase.AwaitingManualRelease, transition.after.phase)
        assertEquals(null, transition.after.reason)
    }

    @Test
    fun releaseWithBufferedFinalRecordsAgentSubmittingAndManualReleaseReason() {
        val stateMachine = TaskVoiceTurnStateMachine()

        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        stateMachine.onAsrReady("dialog_asr")
        stateMachine.onAsrFinalBuffered("给小明打电话", "dialog_asr")
        val transition = stateMachine.onManualReleaseSubmit("给小明打电话", "bottom_release")

        assertEquals(TaskVoiceTurnPhase.AgentSubmitting, transition.after.phase)
        assertEquals(TaskVoiceCloseReason.ManualRelease, transition.after.reason)
    }

    @Test
    fun manualTtsInterruptCanStartManualAsrOrReturnIdle() {
        val stateMachine = TaskVoiceTurnStateMachine()

        stateMachine.onTtsPlaybackStarted("agent_signal")
        val bottomPress = stateMachine.onManualTtsInterrupt("bottom_press", startAsrAfter = true)

        assertEquals(TaskVoiceTurnPhase.TtsPlaying, bottomPress.before.phase)
        assertEquals(TaskVoiceTurnPhase.AsrConnecting, bottomPress.after.phase)
        assertEquals(TaskVoiceCloseReason.ManualTtsInterrupt, bottomPress.after.reason)

        stateMachine.onTtsPlaybackStarted("agent_signal")
        val explicitControl = stateMachine.onManualTtsInterrupt("explicit_control", startAsrAfter = false)

        assertEquals(TaskVoiceTurnPhase.Idle, explicitControl.after.phase)
        assertEquals(TaskVoiceCloseReason.ManualTtsInterrupt, explicitControl.after.reason)
    }

    @Test
    fun providerCloseErrorAndTimeoutUseStableReasons() {
        val stateMachine = TaskVoiceTurnStateMachine()

        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        assertEquals(TaskVoiceCloseReason.ProviderClosed, stateMachine.onProviderClosed("dialog_asr").after.reason)

        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        assertEquals(TaskVoiceCloseReason.ProviderError, stateMachine.onProviderError("dialog_asr").after.reason)

        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        assertEquals(
            TaskVoiceCloseReason.ManualAsrTimeout60s,
            stateMachine.onManualAsrTimeout("bottom_press").after.reason
        )
    }

    @Test
    fun transitionLogLineContainsStableFieldsAndPreview() {
        val logs = mutableListOf<String>()
        val stateMachine = TaskVoiceTurnStateMachine(logs::add)

        stateMachine.onAsrPartial(
            "这是一段很长很长很长很长很长很长很长很长的用户输入",
            "dialog_asr"
        )

        val line = logs.single()
        assertTrue(line.contains("VOICE_TURN_STATE"))
        assertTrue(line.contains("event=asr_partial"))
        assertTrue(line.contains("phaseBefore=idle"))
        assertTrue(line.contains("phaseAfter=asr_listening"))
        assertTrue(line.contains("reason=none"))
        assertTrue(line.contains("source=dialog_asr"))
        assertTrue(line.contains("text=这是一段"))
    }
}
