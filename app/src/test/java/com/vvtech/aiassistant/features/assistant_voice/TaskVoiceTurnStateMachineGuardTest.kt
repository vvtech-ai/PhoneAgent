package com.vvtech.aiassistant.features.assistant_voice

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskVoiceTurnStateMachineGuardTest {

    @Test
    fun legacyTaskVoiceContractIsCompatibilityAliasToVoiceStateMachineBoundary() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/TaskVoiceRuntimeContract.kt")
            .readText()

        assertTrue(source.contains("typealias TaskVoiceCloseReason"))
        assertTrue(source.contains("features.assistant_voice.TaskVoiceCloseReason"))
        assertTrue(source.contains("typealias TaskVoiceTurnPhase"))
        assertTrue(source.contains("features.assistant_voice.TaskVoiceTurnPhase"))
        assertTrue(source.contains("typealias TaskVoiceTurnSnapshot"))
        assertTrue(source.contains("features.assistant_voice.TaskVoiceTurnSnapshot"))
    }

    @Test
    fun voiceRuntimeHandlerOwnsStateMachineAndBridgeMethods() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceRuntimeHandler.kt")
            .readText()
        val watchdog = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceAsrWatchdogController.kt")
            .readText()
        val assistantSpeech = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRealtimeAssistantSpeechHandler.kt")
            .readText()
        val lifecycle = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeLifecycleController.kt")
            .readText()
        val session = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeSessionController.kt")
            .readText()
        val recognizedQueue = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRecognizedTurnQueueController.kt")
            .readText()
        val fallbackSpeech = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceFallbackSpeechEventHandler.kt")
            .readText()
        val localTranscript = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRealtimeLocalTranscriptHandler.kt")
            .readText()

        assertTrue(source.contains("TaskVoiceTurnStateMachine"))
        assertTrue(source.contains("private val taskVoiceTurnStateMachine"))
        assertTrue(source.contains("VoiceAsrWatchdogController"))
        assertTrue(source.contains("VoiceRealtimeAssistantSpeechHandler"))
        assertTrue(source.contains("VoiceRuntimeLifecycleController"))
        assertTrue(source.contains("VoiceRuntimeSessionController"))
        assertTrue(source.contains("VoiceRecognizedTurnQueueController"))
        assertTrue(source.contains("VoiceFallbackSpeechEventHandler"))
        assertTrue(source.contains("VoiceRealtimeLocalTranscriptHandler"))
        assertTrue(source.contains("asrWatchdogController.markAsrReady(source)"))
        assertTrue(source.contains("asrWatchdogController.startManualAsrSessionTimeout(source)"))
        assertTrue(source.contains("realtimeLocalTranscriptHandler.submitPendingStructuredTurn(understanding, reason)"))
        assertTrue(source.contains("realtimeAssistantSpeechHandler.handleRealtimeStructuredAssistantResponse(understanding)"))
        assertTrue(assistantSpeech.contains("fun handleRealtimeAssistantTranscript"))
        assertTrue(assistantSpeech.contains("fun handleRealtimeStructuredAssistantResponse"))
        assertTrue(source.contains("lifecycleController.stopVoiceInteraction(reason)"))
        assertTrue(source.contains("lifecycleController.stopRealtimeSession()"))
        assertTrue(source.contains("lifecycleController.resumeListeningAfterTts()"))
        assertTrue(source.contains("lifecycleController.startBackendSpeechFallback()"))
        assertTrue(watchdog.contains("private var asrWatchdogGeneration"))
        assertTrue(watchdog.contains("private var manualAsrTimeoutGeneration"))
        assertTrue(watchdog.contains("private var latestAsrPartialText"))
        assertTrue(watchdog.contains("ASR_WATCHDOG partial_commit_timeout"))
        assertTrue(assistantSpeech.contains("onDone = callbacks::resumeListeningAfterTts"))
        assertTrue(assistantSpeech.contains("onError = callbacks::resumeListeningAfterTts"))
        assertTrue(assistantSpeech.contains("structured_backend_state_machine"))
        assertTrue(lifecycle.contains("fun stopVoiceInteraction"))
        assertTrue(lifecycle.contains("fun stopRealtimeSession"))
        assertTrue(lifecycle.contains("fun resumeListeningAfterTts"))
        assertTrue(lifecycle.contains("fun startBackendSpeechFallback"))
        assertTrue(lifecycle.contains("pauseVoiceAfterBackendSpeechFallbackFailure"))
        assertTrue(lifecycle.contains("resumeListeningAfterTts: manual ASR gate keeps session paused"))
        assertTrue(lifecycle.contains("VOICE_TASK_ASR backend fallback failed"))
        assertTrue(session.contains("fun startApiListening"))
        assertTrue(session.contains("ContextCompat.checkSelfPermission"))
        assertTrue(session.contains("Manifest.permission.RECORD_AUDIO"))
        assertTrue(session.contains("callbacks.cancelAsrInputWatchdogs(\"missing_record_audio_permission\")"))
        assertTrue(session.contains("voiceDuplexCoordinator.stopOpenListening("))
        assertTrue(session.contains("awaitLateFinal = preserveLateFinalGrace"))
        assertTrue(session.contains("callbacks.startBackendSpeechFallback()"))
        assertTrue(session.contains("activeInteractionChannel == InteractionChannel.VOICE"))
        assertTrue(source.contains("sessionController.startApiListening(trigger)"))
        assertTrue(source.contains("sessionController.startTaskVoiceAsrSession(startReason, onEvent, beforeStart)"))
        assertTrue(source.contains("sessionController.ensureRealtimeSession(silentResume)"))
        assertTrue(source.contains("recognizedTurnQueueController.resetDedup()"))
        assertTrue(source.contains("recognizedTurnQueueController.enqueueRecognizedTurn(text)"))
        assertTrue(recognizedQueue.contains("private var lastRecognizedTurnFingerprint"))
        assertTrue(recognizedQueue.contains("private const val MAX_QUEUED_RECOGNIZED_TURNS = 3"))
        assertTrue(recognizedQueue.contains("queuedRecognizedTurns.addLast(normalized)"))
        assertTrue(recognizedQueue.contains("submitRecognizedTurn(normalized)"))
        assertFalse(source.contains("lastRecognizedTurnFingerprint"))
        assertFalse(source.contains("RECOGNIZED_TURN_DEDUP_WINDOW_MS"))
        assertTrue(source.contains("fallbackSpeechEventHandler.handleLiveTranscriptionEvent(event)"))
        assertTrue(source.contains("fallbackSpeechEventHandler.handleSpeechEvent(event)"))
        assertTrue(fallbackSpeech.contains("LiveSpeechTranscriptionSocketClient.Event.FinalTranscript"))
        assertTrue(fallbackSpeech.contains("callbacks.enqueueRecognizedTurn(event.text)"))
        assertTrue(fallbackSpeech.contains("backend_fallback_closed"))
        assertTrue(fallbackSpeech.contains("SpeechRecognitionEvent.Error"))
        assertTrue(fallbackSpeech.contains("scheduleAutoResumeListening(AutoResumeListeningDelayMillis)"))
        assertFalse(source.contains("LiveSpeechTranscriptionSocketClient.Event.FinalTranscript"))
        assertFalse(source.contains("SpeechRecognitionEvent.Error ->"))
        assertTrue(localTranscript.contains("NoInterruptCapability.logKey"))
        assertTrue(localTranscript.contains("localTtsPlaying=true"))
        assertTrue(localTranscript.contains("looksLikeAsrMetadata(normalized)"))
        assertTrue(localTranscript.contains("callbacks.markAsrPartial(normalized, \"realtime_local\")"))
        assertTrue(localTranscript.contains("callbacks.enqueueRecognizedTurn(normalized)"))
        assertTrue(localTranscript.contains("submitRecognizedTurn(recognized, understanding, assistantResponseText)"))
        assertFalse(source.contains("VOICE_ASR_METADATA_PATTERN"))
        assertFalse(source.contains("ASR final transcript filtered (SDK metadata)"))
        assertTrue(source.contains("VoiceRuntimeEventRecorder()"))
        assertFalse(source.contains("RealtimeRuntimeEvent"))
        assertFalse(source.contains("RuntimeStateLogger"))
        assertFalse(source.contains("VoiceTranscriptSpeaker"))
        assertFalse(source.contains("private fun handleVoiceEvent"))
        assertFalse(source.contains("handleRealtimeLocalTranscript(text, definite)"))
        assertFalse(source.contains("handleRealtimeAssistantTranscript(text, definite)"))
        assertTrue(source.lines().size < 500)
        assertTrue(source.contains("internal fun recordManualAsrPress"))
        assertTrue(source.contains("internal fun recordManualReleaseSubmit"))
        assertTrue(source.contains("internal fun recordAsrFinalBuffered"))
        assertTrue(source.contains("internal fun recordTtsPlaybackStarted"))
        assertTrue(source.contains("internal fun recordTtsPlaybackCompleted"))
        assertTrue(source.contains("internal fun markAsrClosed"))
    }

    @Test
    fun manualEntryAndDuplexCoordinatorOnlyBridgeVoiceTurnEvents() {
        val entry = File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/VoiceEntryActionHandler.kt")
            .readText()
        val manualControl = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt")
            .readText()
        val playback = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexPlaybackController.kt")
            .readText()
        val completion = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexCompletionController.kt")
            .readText()
        val asrEventHandler = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt")
            .readText()

        assertTrue(entry.contains("manualControlHandler.onManualAsrPress()"))
        assertTrue(entry.contains("manualControlHandler.onManualAsrRelease()"))
        assertTrue(entry.contains("manualControlHandler.onTtsInterrupted()"))
        assertTrue(manualControl.contains("recordManualAsrPress(ttsPlaying = ttsPlaying, source = \"bottom_press\")"))
        assertTrue(
            manualControl.contains(
                "recordManualReleaseSubmit(releaseSubmitTranscript, \"bottom_release_no_capture\")"
            )
        )
        assertTrue(manualControl.contains("\"tail_capture_no_active_asr\""))
        assertTrue(
            manualControl.contains(
                "recordManualReleaseSubmit(timeoutTranscript, \"manual_release_fallback\")"
            )
        )
        assertTrue(manualControl.contains("recordManualTtsInterrupt(\"explicit_control\", startAsrAfter = false)"))

        assertTrue(asrEventHandler.contains("recordAsrFinalBuffered(mergedFinalText, \"dialog_asr\")"))
        assertTrue(asrEventHandler.contains("recordAgentSubmitting(mergedFinalText, \"dialog_asr_final\")"))
        assertTrue(playback.contains("recordTtsPlaybackStarted(\"agent_tts_playback_started\")"))
        assertTrue(completion.contains("recordTtsPlaybackCompleted(\"agent_tts_playback_complete\")"))
        assertTrue(completion.contains("recordTtsPlaybackFailed(\"agent_tts_playback_failed\")"))
        assertTrue(asrEventHandler.contains("markAsrClosed(\"dialog_asr_closed\")"))
    }

    @Test
    fun agentOptionSelectionStopsOnlyTtsPlayback() {
        val entry = File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/VoiceEntryActionHandler.kt")
            .readText()
        val body = entry.substringAfter("fun stopTtsPlaybackForOptionSelection()")
            .substringBefore("fun startVoiceInteraction()")
        val host = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantSingleFlowPageHost.kt")
            .readText()

        assertTrue(host.contains("assistantViewModel.stopTtsPlaybackForOptionSelection()"))
        assertTrue(body.contains("ttsBridge.interrupt()"))
        assertTrue(body.contains("assistantSpeechPlayer.stop()"))
        assertFalse(body.contains("agentStreamHandler.interruptCurrentStream()"))
        assertFalse(body.contains("closeTaskVoiceRealtime("))
        assertFalse(body.contains("voiceManuallyPaused"))
        assertFalse(body.contains("processingTurn"))
    }
}
