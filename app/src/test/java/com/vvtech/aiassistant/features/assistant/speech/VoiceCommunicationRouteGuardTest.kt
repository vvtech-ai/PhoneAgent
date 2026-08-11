package com.vvtech.aiassistant.features.assistant.speech

import android.media.AudioManager
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCommunicationRouteGuardTest {

    @Test
    fun dialogAsrDoesNotFallBackToSystemSpeechRecognizerByDefault() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceRuntimeHandler.kt").readText()

        assertFalse(
            "Default dialog ASR should not route into Android SpeechRecognizer; it is not controllable as VOICE_COMMUNICATION.",
            source.contains("speechRecognizer.start(")
        )
    }

    @Test
    fun qwenTaskAsrDoesNotEnableAutomaticGainControl() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/QwenTaskAsrSocketClient.kt").readText()

        assertFalse(
            "Qwen task ASR should avoid explicit AGC because it can raise noisy environments and echo tails.",
            source.contains("AutomaticGainControl.create(")
        )
    }

    @Test
    fun taskTtsUsesMediaAttributesWithoutLegacyVendorExceptions() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/TtsAudioAttributes.kt").readText()

        assertTrue(
            "All devices must use media attributes so headset routing and media volume remain effective.",
            source.contains("setUsage(AudioAttributes.USAGE_MEDIA)")
        )
        assertTrue(
            "Android 10+ TTS playback must reject app-level capture so vivo cannot divert it to remote_submix.",
            source.contains("setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_SYSTEM)")
        )
        assertFalse(source.contains("setLegacyStreamType("))
        assertFalse(source.contains("LEGACY_STREAM_TTS"))
        assertEquals(AudioManager.STREAM_MUSIC, TtsAudioAttributes.volumeControlStream())
        assertFalse(TtsAudioAttributes.shouldUseVoiceCommunicationUsage())
    }

    @Test
    fun mainActivityVolumeKeysFollowMediaTtsRoute() {
        val source = File("src/main/java/com/vvtech/aiassistant/MainActivity.kt").readText()

        assertTrue(
            "Task voice TTS volume keys must follow the media route used by playback.",
            source.contains("volumeControlStream = TtsAudioAttributes.volumeControlStream()")
        )
    }

    @Test
    fun simplexTtsPlaybackDoesNotEnterConversationAudioRoute() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexPlaybackController.kt").readText()
        val body = source.substringAfter("fun prepareSimplexPlayback")
            .substringBefore("private fun isVoiceMode")

        assertFalse(
            "Task-stage simplex TTS must stay on normal assistant/media playback, not MODE_IN_COMMUNICATION.",
            body.contains("ensureVoiceConversationAudioRoute")
        )
        assertFalse(
            "Task-stage simplex TTS should not prepare communication audio mode.",
            body.contains("prepareCommunicationAudioMode")
        )
    }

    @Test
    fun taskOpenListeningDoesNotEnterConversationAudioRoute() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val body = source.substringAfter("internal fun startOpenListening()")
            .substringBefore("internal fun stopOpenListening")

        assertFalse(
            "Task-stage ASR should keep the normal recording route and must not switch to MODE_IN_COMMUNICATION.",
            body.contains("ensureVoiceConversationAudioRoute")
        )
    }

    @Test
    fun taskOpenListeningDoesNotInterruptWarmTtsBridge() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val body = source.substringAfter("internal fun startOpenListening()")
            .substringBefore("internal fun stopOpenListening")

        assertFalse(
            "Starting the next simplex ASR turn after natural TTS completion should not interrupt or close the warm TTS bridge.",
            body.contains("ttsBridge.interrupt()")
        )
    }

    @Test
    fun taskSimplexFlowDoesNotArmOrFilterEchoGuard() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val asrEventHandler = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceTaskAsrEventHandler.kt").readText()
        val playbackCompleteBody = source.substringAfter("internal fun onAgentTtsPlaybackComplete()")
            .substringBefore("internal fun onAgentTtsPlaybackFailed")

        assertFalse(
            "Current task voice runtime must not expose a TTS barge-in arm path.",
            source.contains("startBargeInListening")
        )
        assertFalse(
            "TTS completion should not queue ASR capture or echo filtering.",
            playbackCompleteBody.contains("requestBarge") || playbackCompleteBody.contains("BargeIn")
        )
        assertFalse(
            "Task ASR transcript handling should not use local TTS interrupt score fields.",
            asrEventHandler.contains("interruptScore") || asrEventHandler.contains("isPvad")
        )
    }

    @Test
    fun qwenTaskAsrDoesNotForceCommunicationAudioMode() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/QwenTaskAsrSocketClient.kt").readText()

        assertFalse(
            "Task ASR should use normal recording route and must not force MODE_IN_COMMUNICATION.",
            source.contains("audioManager.mode = AudioManager.MODE_IN_COMMUNICATION")
        )
    }

    @Test
    fun qwenTaskAsrDoesNotUseVoiceCommunicationRecorderSource() {
        val source = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/QwenTaskAsrSocketClient.kt").readText()

        assertFalse(
            "Task ASR should avoid MediaRecorder.AudioSource.VOICE_COMMUNICATION in the simplex task flow.",
            source.contains("MediaRecorder.AudioSource.VOICE_COMMUNICATION")
        )
    }

    @Test
    fun voiceDuplexAudioRouteModeLogicLivesInDedicatedController() {
        val coordinator = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val audioRoute = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexAudioRouteController.kt").readText()

        assertTrue(coordinator.contains("VoiceDuplexAudioRouteController"))
        assertTrue(coordinator.contains("audioRouteController.restoreNormalAudioMode(reason, force)"))
        assertTrue(coordinator.contains("audioRouteController.keepSpeechOutputOnSpeaker()"))
        assertFalse(
            "VoiceDuplexCoordinator should no longer inline AudioManager mode switching.",
            coordinator.contains("AudioManager.MODE_IN_COMMUNICATION") ||
                coordinator.contains("TtsAudioModeController.isCommunicationModeActive()")
        )
        assertTrue(audioRoute.contains("private var voiceConversationRouteActive"))
        assertTrue(audioRoute.contains("AudioManager.MODE_IN_COMMUNICATION"))
        assertTrue(audioRoute.contains("TtsAudioModeController.isCommunicationModeActive()"))
        assertTrue(audioRoute.contains("VOICE_DIAG audioMode conversationRoute enter"))
        assertTrue(audioRoute.contains("VOICE_DIAG audioMode keepSpeaker"))
    }

    @Test
    fun voiceDuplexPlaybackPreprocessingLivesInDedicatedController() {
        val coordinator = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val playback = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexPlaybackController.kt").readText()

        assertTrue(coordinator.contains("VoiceDuplexPlaybackController"))
        assertTrue(coordinator.contains("playbackController.feedAgentTextDelta(delta)"))
        assertTrue(coordinator.contains("playbackController.feedAgentSignalText(text)"))
        assertFalse(
            "VoiceDuplexCoordinator should no longer own active speech source/text state.",
            coordinator.contains("private var activeSpeechSource") ||
                coordinator.contains("private var activeSpeechText")
        )
        assertTrue(playback.contains("private var activeSpeechSource"))
        assertTrue(playback.contains("private var activeSpeechText"))
        assertTrue(playback.contains("fun feedAgentTextDelta"))
        assertTrue(playback.contains("fun feedAgentSignalText"))
        assertTrue(playback.contains("fun prepareSimplexPlayback"))
        assertTrue(playback.contains("TTS_DIAG"))
        assertTrue(playback.contains("VOICE_DUPLEX simplex playback clears ASR"))
        assertFalse(
            "Playback preprocessing must not reintroduce automatic barge-in.",
            playback.contains("startBargeInListening") ||
                playback.contains("requestBarge")
        )
    }

    @Test
    fun voiceDuplexCompletionLivesInDedicatedController() {
        val coordinator = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt").readText()
        val completion = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexCompletionController.kt").readText()

        assertTrue(coordinator.contains("VoiceDuplexCompletionController"))
        assertTrue(coordinator.contains("completionController.onAgentTtsPlaybackComplete()"))
        assertTrue(coordinator.contains("completionController.onAgentTtsPlaybackFailed(error)"))
        assertTrue(coordinator.contains("completionController.speakLocal(text, source, languageCode, onStart, onDone, onError)"))
        assertTrue(coordinator.contains("completionController.markPausedIfVoiceCanContinue(reason)"))
        assertFalse(
            "VoiceDuplexCoordinator should no longer inline completion/pause state cleanup.",
            coordinator.contains("private fun finishLocalPlayback") ||
                coordinator.contains("private fun shouldShowPausedPrompt") ||
                coordinator.contains("VOICE_DUPLEX recoverable pause")
        )
        assertTrue(completion.contains("fun onAgentTtsPlaybackComplete"))
        assertTrue(completion.contains("fun onAgentTtsPlaybackFailed"))
        assertTrue(completion.contains("fun speakLocal"))
        assertTrue(completion.contains("fun pauseVoiceAfterRealtimeFailure"))
        assertTrue(completion.contains("private fun finishLocalPlayback"))
        assertTrue(completion.contains("private fun shouldShowPausedPrompt"))
        assertTrue(completion.contains("VOICE_DUPLEX recoverable pause"))
        assertFalse(
            "TTS completion must not auto-start task ASR.",
            completion.substringAfter("fun onAgentTtsPlaybackComplete")
                .substringBefore("fun onAgentTtsPlaybackFailed")
                .contains("startOpenListening()")
        )
    }

    @Test
    fun voiceDuplexRetryLivesInDedicatedControllerAndCoordinatorIsBelowFiveHundredLines() {
        val coordinatorFile = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceDuplexCoordinator.kt")
        val coordinator = coordinatorFile.readText()
        val retry = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexRetryController.kt").readText()

        assertTrue(coordinator.contains("VoiceDuplexRetryController"))
        assertTrue(coordinator.contains("retryController.restartListeningAfterDroppedTranscript(reason)"))
        assertFalse(
            "VoiceDuplexCoordinator should no longer inline dropped transcript retry or unused ready timeout recovery.",
            coordinator.contains("VOICE_DUPLEX dropped transcript no resume") ||
                coordinator.contains("scheduleAsrReadyTimeoutRecovery") ||
                coordinator.contains("AsrReadyTimeoutMs")
        )
        assertTrue(retry.contains("VOICE_DUPLEX dropped transcript no resume"))
        assertTrue(retry.contains("callbacks.startOpenListening()"))
        assertTrue(retry.contains("RestartAfterStopDelayMs"))
        assertTrue(
            "VoiceDuplexCoordinator should be below the 500-line architecture threshold after R17 retry extraction.",
            coordinatorFile.readLines().size < 500
        )
    }
}
