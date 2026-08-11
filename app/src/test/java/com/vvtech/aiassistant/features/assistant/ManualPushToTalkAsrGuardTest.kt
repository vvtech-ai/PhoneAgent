package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ManualPushToTalkAsrGuardTest {

    @Test
    fun pureVoiceBottomControlUsesPressAndReleaseCallbacks() {
        val visuals = File("src/main/java/com/vvtech/aiassistant/features/assistant/PureVoiceStageVisuals.kt").readText()
        val content = File("src/main/java/com/vvtech/aiassistant/features/assistant/PureVoiceStageContent.kt").readText()
        val dockControls = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/input/PureVoiceInputDockControls.kt"
        ).readText()

        assertTrue(
            "Pure voice bottom control should expose separate press/release callbacks for hold-to-talk.",
            visuals.contains("onPress: () -> Unit") &&
                visuals.contains("onRelease: () -> Unit")
        )
        assertTrue(
            "Pure voice stage should route voice actions into the input boundary.",
            content.contains("onMicClick = args.onMicClick") &&
                content.contains("onStop = args.onStop")
        )
        assertTrue(
            "Pure voice input boundary should map hold-to-talk press/release to the voice callbacks.",
            dockControls.contains("onPress =") &&
                dockControls.contains("callbacks.onMicClick()") &&
                dockControls.contains("onRelease =") &&
                dockControls.contains("callbacks.onStop()")
        )
    }

    @Test
    fun agentPlaybackCompletionDoesNotAutoRestartTaskAsr() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val playbackCompleteBody = source.substringAfter("internal fun onAgentTtsPlaybackComplete()")
            .substringBefore("internal fun onAgentTtsPlaybackFailed")

        assertFalse(
            "Natural TTS completion should no longer auto restart task ASR; next ASR must come from manual button press.",
            playbackCompleteBody.contains("startOpenListening()")
        )
    }

    @Test
    fun manualAsrFlowKeepsExplicitSixtySecondTimeoutMarker() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceAsrWatchdogController.kt").readText()

        assertTrue(
            "Manual hold-to-talk ASR should keep an explicit 60s timeout path and stable reason marker.",
            source.contains("startManualAsrSessionTimeout") &&
                source.contains("manual_asr_timeout_60s")
        )
    }

    @Test
    fun manualPttPartialsDoNotAutoCommitStalePartial() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceAsrWatchdogController.kt").readText()
        val partialBody = source.substringAfter("fun markAsrPartial")
            .substringBefore("fun markAsrFinal")

        assertTrue(
            "Manual hold-to-talk partials must not be auto-submitted by the stale partial timeout; release or 60s timeout owns submission.",
            partialBody.contains("manualAsrButtonPressed") &&
                partialBody.contains("partial_commit_suppressed") &&
                partialBody.indexOf("partial_commit_suppressed") < partialBody.indexOf("asrPartialCommitJob = viewModelScope.launch")
        )
    }

    @Test
    fun manualAsrTimeoutSurvivesBufferedFinalAfterRecognizerStops() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceAsrWatchdogController.kt").readText()
        val timeoutBody = source.substringAfter("private fun handleManualAsrTimeout")
            .substringBefore("private fun commitLatestAsrPartialIfStale")

        assertTrue(
            "Manual 60s timeout should still fire when ASR already produced a buffered final but the user keeps holding the button.",
            timeoutBody.contains("hasManualHoldState") &&
                timeoutBody.contains("pendingManualAsrFinalTranscript") &&
                timeoutBody.contains("!hasManualHoldState") &&
                timeoutBody.contains("fallbackExtendsBufferedFinal") &&
                timeoutBody.contains("autoSubmitCandidate")
        )
    }

    @Test
    fun manualAsrTimeoutDoesNotMarkBusyBeforeAutoSubmit() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceAsrWatchdogController.kt").readText()
        val timeoutAutoSubmitBody = source.substringAfter("if (autoSubmitText.isNotBlank())")
            .substringBefore("return@with")

        assertTrue(
            "Manual 60s timeout should still enqueue the recognized text for submission.",
            timeoutAutoSubmitBody.contains("enqueueRecognizedTurn(autoSubmitText)")
        )
        assertFalse(
            "Manual 60s timeout must not set processingTurn=true before enqueue, otherwise enqueueRecognizedTurn treats the turn as busy and only queues it.",
            timeoutAutoSubmitBody.contains("processingTurn = true")
        )
    }

    @Test
    fun manualReleaseUsesOneBoundedFinalizingWindow() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val releaseBody = source.substringAfter("fun onManualAsrRelease()")
            .substringBefore("fun onTtsInterrupted()")

        assertTrue(
            "Manual release should keep capture alive during one bounded finalizing state and submit its latest snapshot at the deadline.",
            releaseBody.contains("fallbackTranscript") &&
                releaseBody.contains("ManualAsrFinalizeMaxCaptureMillis") &&
                releaseBody.contains("manualAsrFinalizing = true") &&
                !releaseBody.contains("ManualFinishFallbackDelayMillis") &&
                releaseBody.contains("enqueueRecognizedTurn")
        )
    }

    @Test
    fun manualReleaseCapturesAtMostTwoSecondsBeforeStoppingAsr() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val policy = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/ManualAsrTranscriptPolicy.kt").readText()
        val releaseBody = source.substringAfter("fun onManualAsrRelease()")
            .substringBefore("fun onTtsInterrupted()")
        val finalizingBody = releaseBody.substringAfter("manualAsrReleaseFallbackJob = viewModelScope.launch")
        val captureDeadlineIndex = finalizingBody.indexOf("delay(ManualAsrFinalizeMaxCaptureMillis)")
        val stopIndex = finalizingBody.indexOf("stopApiListening(preserveLateFinalGrace = false)")

        assertTrue(
            "ACTION_UP must keep the same capture alive for at most two seconds before stop/flush.",
            policy.contains("ManualAsrFinalizeMaxCaptureMillis = 2_000L") &&
                releaseBody.contains("release finalizing armed") &&
                captureDeadlineIndex >= 0 &&
                stopIndex > captureDeadlineIndex
        )
    }

    @Test
    fun manualReleaseFinalizingCannotBeRetriggered() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val pressBody = source.substringAfter("fun onManualAsrPress()")
            .substringBefore("fun onManualAsrRelease()")

        assertTrue(
            "The main voice action must remain unavailable while the released utterance is finalizing.",
            pressBody.contains("internalUiState.value.manualAsrFinalizing") &&
                pressBody.contains("press blocked reason=release_finalizing") &&
                pressBody.contains("return@with")
        )
    }

    @Test
    fun manualReleaseDeadlineIsScopedToTheSamePressGeneration() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val releaseBody = source.substringAfter("fun onManualAsrRelease()")
            .substringBefore("fun onTtsInterrupted()")

        assertTrue(
            "Manual release deadline should only submit for the same press generation and close that capture before delivery.",
            releaseBody.contains("val releaseGeneration = manualAsrPressGeneration") &&
                releaseBody.contains("manualAsrPressGeneration != releaseGeneration") &&
                releaseBody.contains("taskAsrClient.closeNow(\"manual_release_capture_deadline\")")
        )
    }

    @Test
    fun repeatedTextAfterNewAsrInputIsNotBlockedByGlobalTranscript() {
        val manualControl =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val sessionController =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeSessionController.kt").readText()
        val releaseBody = manualControl.substringAfter("fun onManualAsrRelease()")
            .substringBefore("fun onTtsInterrupted()")

        assertTrue(
            "Every allowed ASR input must start a new dedup generation, and release deadline delivery must only deduplicate inside that generation.",
            sessionController.contains("voiceRecognizedInputDedupTracker.beginInput()") &&
                releaseBody.contains("voiceRecognizedInputDedupTracker.isDuplicateInCurrentInput(deadlineTranscript)") &&
                !releaseBody.contains("lastCommittedUserTranscript == deadlineTranscript")
        )
    }

    @Test
    fun taskAsrReadyIsIgnoredAfterManualRelease() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt").readText()
        val readyBody = source.substringAfter("private fun handleReady()")
            .substringBefore("private fun clearAsrUi")

        assertTrue(
            "Late Ready events after manual release should be ignored behind dialogAsrActive gate.",
            readyBody.contains("if (!callbacks.dialogAsrActive) {") &&
                readyBody.contains("late_ready_after_release")
        )
    }

    @Test
    fun taskAsrPartialsUpdateLiveUserTranscriptImmediately() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt").readText()
        val partialBody = source.substringAfter("private fun handlePartial")
            .substringBefore("private fun handleFinal")

        assertTrue(
            "Task ASR partials should update liveUserTranscript so the user sees speech in real time, including any buffered manual prefix.",
            partialBody.contains("displayText") &&
                partialBody.contains("mergeManualAsrTranscript") &&
                partialBody.contains("liveUserTranscript = displayText")
        )
    }

    @Test
    fun taskAsrCoordinatorKeepsLateFinalGraceOnlyForManualReleaseWindow() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()

        assertTrue(
            "Task ASR coordinator should keep an explicit late-final grace window for manual release and clear it when the window is cancelled.",
            source.contains("awaitingManualReleaseFinal") &&
                source.contains("cancelManualReleaseLateFinal")
        )
    }

    @Test
    fun taskAsrFinalIsBufferedWhileManualButtonIsStillHeld() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt").readText()
        val finalBody = source.substringAfter("private fun handleFinal")
            .substringBefore("private fun handleError")

        assertTrue(
            "Manual hold-to-talk should buffer dialog ASR final results, keep the manual session open, and merge multi-segment transcripts before release.",
            finalBody.contains("keepManualSessionOpen") &&
                finalBody.contains("final_buffered_dialog_asr") &&
                finalBody.contains("pendingManualAsrFinalTranscript = mergedFinalText") &&
                finalBody.contains("mergeManualAsrTranscript") &&
                finalBody.contains("awaiting_release")
        )
    }

    @Test
    fun taskAsrCoordinatorDelegatesProviderEventsToHandler() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val body = source.substringAfter("private fun handleDialogAsrEvent")
            .substringBefore("private fun pauseVoiceAfterRealtimeFailure")

        assertTrue(
            "Task ASR provider event reducer should live in VoiceTaskAsrEventHandler, with coordinator only delegating events.",
            source.contains("VoiceTaskAsrEventHandler") &&
                body.contains("taskAsrEventHandler.handle(event)")
        )
    }

    @Test
    fun manualReleaseKeepsResolvedSnapshotForCaptureDeadline() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val releaseBody = source.substringAfter("fun onManualAsrRelease()")
            .substringBefore("fun onTtsInterrupted()")

        assertTrue(
            "Manual release should retain and merge the resolved snapshot until a provider final arrives or the two-second deadline expires.",
            releaseBody.contains("resolveManualAsrReleaseTranscript") &&
                releaseBody.contains("releaseSubmitTranscript") &&
                releaseBody.contains("deadlineTranscript") &&
                releaseBody.contains("enqueueRecognizedTurn(deadlineTranscript)")
        )
    }

    @Test
    fun providerFinalDuringFinalizingEndsTheWindowImmediately() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt").readText()
        val finalBody = source.substringAfter("private fun handleFinal")
            .substringBefore("private fun handleError")

        assertTrue(
            "A provider final received during the release finalizing window must cancel the deadline and clear the UI state.",
            finalBody.contains("releaseFinalizing") &&
                finalBody.contains("callbacks.awaitingManualReleaseFinal || releaseFinalizing") &&
                finalBody.contains("if (!keepManualSessionOpen && validFinalText)") &&
                finalBody.contains("manualAsrReleaseFallbackJob?.cancel()") &&
                finalBody.contains("manualAsrFinalizing = if (!keepManualSessionOpen && validFinalText)")
        )
    }

    @Test
    fun invalidProviderFinalKeepsFinalizingCaptureOpen() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt").readText()
        val finalBody = source.substringAfter("private fun handleFinal")
            .substringBefore("private fun handleError")
        val invalidFinalGuard = finalBody.indexOf("if (releaseFinalizing && !validFinalText)")
        val closeCapture = finalBody.indexOf("callbacks.dialogAsrActive = false")

        assertTrue(
            "Blank or metadata Final must be ignored before the finalizing capture is closed.",
            invalidFinalGuard >= 0 &&
                closeCapture > invalidFinalGuard &&
                finalBody.substring(invalidFinalGuard, closeCapture).contains("return")
        )
    }

    @Test
    fun queuedAsrEventsAreScopedToTheirCaptureGeneration() {
        val taskCoordinator = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt"
        ).readText()
        val fallbackRuntime = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant/VoiceRuntimeHandler.kt"
        ).readText()

        assertTrue(
            "Task and backend-fallback callbacks must reject events queued by an older capture.",
            taskCoordinator.contains("captureGeneration != taskAsrCaptureGeneration") &&
                taskCoordinator.contains("stale ASR event dropped") &&
                fallbackRuntime.contains("captureGeneration != viewModel.backendSpeechFallbackGeneration") &&
                fallbackRuntime.contains("reason=stale_capture")
        )
    }

    @Test
    fun pureVoiceStopDistinguishesRecordingReleaseFromAiStop() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/SingleFlowNativeDemoScreen.kt").readText()
        val stopBody = source.substringAfter("onPureVoiceStop = {")
            .substringBefore("onPureVoiceCancel =")

        assertTrue(
            "Pure voice Stop should release manual ASR only while recording; AI thinking or speaking should interrupt TTS/stream without closing the task page.",
            stopBody.contains("resolvePureVoiceListeningState") &&
                stopBody.contains("onStopVoiceInteraction?.invoke()") &&
                stopBody.contains("onPauseTtsPlayback?.invoke()")
        )
        assertFalse(
            "Pure voice Stop must not trigger the page-level stop action because that exits the conversation.",
            stopBody.contains("triggerStopAction()")
        )
    }

    @Test
    fun manualPressDuringTtsInterruptsPlaybackAndStartsAsr() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val pressBody = source.substringAfter("fun onManualAsrPress()")
            .substringBefore("fun onManualAsrRelease()")

        assertTrue(
            "Manual ASR press during TTS should log a stable explicit user interrupt reason.",
            pressBody.contains("ManualTtsInterrupt") &&
                pressBody.contains("source=bottom_press")
        )
        assertTrue(
            "Manual ASR press during TTS must interrupt TTS playback and still start the ASR session.",
                pressBody.contains("ttsBridge.interrupt()") &&
                pressBody.contains("agentStreamHandler.interruptCurrentStream()") &&
                pressBody.contains("assistantSpeechPlayer.stop()") &&
                pressBody.contains("startApiListening(VoiceListenTriggers.ManualAsrPress)")
        )
    }

    @Test
    fun explicitTtsControlStillInterruptsPlayback() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceManualControlHandler.kt").readText()
        val body = source.substringAfter("fun onTtsInterrupted()")
            .substringBefore("fun startVoiceInteraction()")

        assertTrue(
            "Explicit user TTS control should still interrupt playback; only automatic ASR/VAD interrupt is removed.",
            body.contains("ManualTtsInterrupt") &&
                body.contains("ttsBridge.interrupt()") &&
                body.contains("agentStreamHandler.interruptCurrentStream()") &&
                body.contains("assistantSpeechPlayer.stop()")
        )
    }

    @Test
    fun taskVoiceAsrEventsDoNotExposeInterruptFields() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/TaskVoiceAsrEvent.kt").readText()

        assertFalse(
            "Task ASR transcript events should no longer expose local TTS interrupt fields.",
            source.contains("interruptScore") || source.contains("isPvad")
        )
    }

    @Test
    fun qwenTaskAsrSocketAllowsOneLateFinalAfterManualStop() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/QwenTaskAsrSocketClient.kt").readText()

        assertTrue(
            "Qwen task ASR socket should allow one late final after stop so trailing words are not lost on manual release.",
            source.contains("acceptLateFinalGeneration") &&
                source.contains("VOICE_QWEN_TASK_ASR allow late final after stop")
        )
    }
}
