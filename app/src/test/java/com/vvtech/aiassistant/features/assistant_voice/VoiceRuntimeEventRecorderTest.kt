package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.domain.realtime.RealtimeCloseReason
import com.vvtech.aiassistant.domain.realtime.RealtimeLifecycleState
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceRuntimeEventRecorderTest {
    @Test
    fun mapsManualReleaseTransitionToVoiceRuntimeEvent() {
        val stateMachine = TaskVoiceTurnStateMachine()
        stateMachine.onManualAsrPress(ttsPlaying = false, source = "bottom_press")
        stateMachine.onAsrReady(source = "provider_ready")
        stateMachine.onAsrFinalBuffered(text = "给小明打电话", source = "asr_final")

        val transition = stateMachine.onManualReleaseSubmit(text = "给小明打电话", source = "bottom_release")
        val event = VoiceRuntimeEventPolicy.transitionEvent(transition, taskId = " task-1 ")
        val logEvent = VoiceRuntimeEventPolicy.logEvent(event)

        assertEquals(RealtimeRuntimeDomain.Voice, event.domain)
        assertEquals("manual_release_submit", event.eventType)
        assertEquals("task-1", event.sessionId)
        assertEquals("app", event.normalizedProvider.wireValue)
        assertEquals(RealtimeLifecycleState.Active, event.normalizedStateBefore.state)
        assertEquals(RealtimeLifecycleState.Active, event.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ManualRelease, event.normalizedReason.reason)
        assertEquals("给小明打电话", event.attributes["transcriptPreview"])
        assertEquals(RuntimeStateLogDomain.VOICE, logEvent.domain)
        assertEquals("task-1", logEvent.taskId)
        assertEquals("manual_release", logEvent.reason)
    }

    @Test
    fun mapsManualTtsInterruptToConnectingVoiceState() {
        val transition = TaskVoiceTurnStateMachine()
            .onManualAsrPress(ttsPlaying = true, source = "bottom_press")
        val event = VoiceRuntimeEventPolicy.transitionEvent(transition, taskId = "task-2")

        assertEquals("manual_asr_press", event.eventType)
        assertEquals(RealtimeLifecycleState.Idle, event.normalizedStateBefore.state)
        assertEquals(RealtimeLifecycleState.Connecting, event.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ManualTtsInterrupt, event.normalizedReason.reason)
    }

    @Test
    fun mapsProviderErrorAndTimeoutCloseReasons() {
        val providerError = TaskVoiceTurnStateMachine()
            .onProviderError(source = "dialog_asr")
        val providerErrorEvent = VoiceRuntimeEventPolicy.transitionEvent(providerError, taskId = "task-3")

        assertEquals(RealtimeLifecycleState.Failed, providerErrorEvent.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ProviderError, providerErrorEvent.normalizedReason.reason)

        val timeout = TaskVoiceTurnStateMachine()
            .onManualAsrTimeout(source = "manual_asr_timeout")
        val timeoutEvent = VoiceRuntimeEventPolicy.transitionEvent(timeout, taskId = "task-4")

        assertEquals(RealtimeLifecycleState.Closed, timeoutEvent.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ManualAsrTimeout60s, timeoutEvent.normalizedReason.reason)
    }

    @Test
    fun voiceRuntimeHandlerConnectsStateMachineToStructuredRecorder() {
        val handler = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceRuntimeHandler.kt")
            .readText(Charsets.UTF_8)
        val stateMachine = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/TaskVoiceTurnStateMachine.kt"
        ).readText(Charsets.UTF_8)
        val recorder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeEventRecorder.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(handler.contains("VoiceRuntimeEventRecorder()"))
        assertTrue(handler.contains("transitionListener = { transition ->"))
        assertTrue(handler.contains("voiceRuntimeEventRecorder.record(transition, activeVoiceTaskId())"))
        assertTrue(stateMachine.contains("transitionListener?.invoke(transition)"))
        assertTrue(recorder.contains("RealtimeRuntimeDomain.Voice"))
        assertTrue(recorder.contains("RuntimeStateLogDomain.VOICE"))
        assertTrue(recorder.contains("RuntimeStateLogger.info(logEvent)"))
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
