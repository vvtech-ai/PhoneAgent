package com.vvtech.aiassistant.features.assistant.speech

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class TtsPlaybackDiagnosticsGuardTest {

    @Test
    fun taskTtsPlaybackRequestsAndReleasesTransientMediaAudioFocus() {
        val focusSource = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/TtsAudioFocusController.kt")
        val playerSource = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/AudioPlayer.kt").readText()

        assertTrue("TTS playback should use a dedicated small AudioFocus helper.", focusSource.exists())
        val focusText = focusSource.readText()
        assertTrue(
            "TTS playback must request transient AudioFocus before media playback.",
            focusText.contains("requestAudioFocus") &&
                focusText.contains("AUDIOFOCUS_GAIN_TRANSIENT")
        )
        assertTrue(
            "TTS playback must abandon AudioFocus after completion or interruption.",
            focusText.contains("abandonAudioFocus")
        )
        assertTrue(
            "AudioPlayer must acquire and release the TTS AudioFocus helper.",
            playerSource.contains("audioFocusController.acquire") &&
                playerSource.contains("audioFocusController.release")
        )
    }

    @Test
    fun taskTtsPlaybackLogsRequiredLifecycleMarkers() {
        val bridgeSource = File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/AgentTtsBridge.kt").readText()
        val playerSource = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/AudioPlayer.kt").readText()
        val focusSource = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/TtsAudioFocusController.kt").readText()
        val playbackSources = playerSource + "\n" + focusSource

        listOf(
            "TTS request started",
            "TTS audio received",
            "TTS returned success",
            "TTS returned failure"
        ).forEach { marker ->
            assertTrue("AgentTtsBridge must log marker: $marker", bridgeSource.contains(marker))
        }
        listOf(
            "player initialization",
            "AudioFocus result",
            "playback started",
            "playback completed",
            "playback exception"
        ).forEach { marker ->
            assertTrue("Playback path must log marker: $marker", playbackSources.contains(marker))
        }
    }

    @Test
    fun audioPlayerKeepsQueueSegmentModelOutOfPlaybackImplementation() {
        val playerFile = File("src/main/java/com/vvtech/aiassistant/features/assistant/speech/AudioPlayer.kt")
        val segmentFile = File("src/main/java/com/vvtech/aiassistant/features/assistant_speech/AudioSegment.kt")
        val playerSource = playerFile.readText()
        val segmentSource = segmentFile.readText()

        assertTrue("AudioPlayer should stay below the 500-line guard.", playerFile.readLines().size < 500)
        assertTrue("AudioSegment model file should exist.", segmentFile.exists())
        assertTrue(segmentSource.contains("internal data class AudioSegment"))
        assertTrue(segmentSource.contains("val format: TtsAudioFormat"))
        assertTrue(playerSource.contains("AudioSegment("))
        assertTrue(playerSource.contains("queue.add(segment)"))
        assertTrue(playerSource.contains("TtsAudioFormat.Mp3 -> mainHandler.post { startMediaPlayback(segment) }"))
        assertTrue(playerSource.contains("TtsAudioFormat.Pcm24k16BitMono -> startPcmPlayback(segment)"))
        assertTrue("AudioPlayer must not inline the segment model.", !playerSource.contains("private data class AudioSegment"))
    }
}
