package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.security.MessageDigest
import java.util.Collections

class AssistantTranslationIntroTest {
    @Test
    fun `selects supported intro language and falls back to english for unknown language`() {
        assertEquals("zh", AssistantTranslationIntroAudio.languageCode("zh-CN"))
        assertEquals("ja", AssistantTranslationIntroAudio.languageCode("ja_JP"))
        assertEquals("en", AssistantTranslationIntroAudio.languageCode("english"))
        assertEquals("en", AssistantTranslationIntroAudio.languageCode("fr"))
        assertEquals("en", AssistantTranslationIntroAudio.languageCode("de-DE"))
    }

    @Test
    fun `converts pcm16 into 20ms pcm16k frames`() {
        val frames = AssistantTranslationIntroAudio.framesFromPcm16(
            pcm16 = ShortArray(480),
            sampleRate = 24_000
        )

        assertEquals(1, frames.size)
        assertEquals(320, frames.single().size)
    }

    @Test
    fun `gate suppresses live input and protects delayed model output`() {
        var now = 1_000L
        val gate = AssistantTranslationIntroGate(nanoTime = { now })

        assertTrue(gate.enter())
        assertTrue(gate.shouldSuppressLiveInput())
        assertTrue(gate.shouldSuppressModelOutput())

        gate.release()
        assertFalse(gate.shouldSuppressLiveInput())
        assertTrue(gate.shouldSuppressModelOutput())

        now += 900_000_000L
        assertFalse(gate.shouldSuppressModelOutput())
    }

    @Test
    fun `gate waits for qwen trigger response boundary instead of fixed grace window`() {
        var now = 1_000L
        val gate = AssistantTranslationIntroGate(nanoTime = { now })

        assertTrue(gate.enter(expectTriggerResponseBoundary = true))
        gate.finishIntroPlayback()

        assertFalse(gate.shouldSuppressLiveInput())
        now += 5_000_000_000L
        assertTrue(gate.shouldSuppressModelOutput())

        assertTrue(gate.completeTriggerResponse())
        assertFalse(gate.shouldSuppressModelOutput())
    }

    @Test
    fun `qwen parser exposes response done as a model turn boundary`() {
        val parser = AssistantQwenEventParser(
            speaker = "local",
            sourceLanguage = "zh",
            targetLanguage = "en",
            outputSampleRate = 16_000
        )

        val event = parser.parse("""{"type":"response.done"}""")

        assertTrue(event === AssistantQwenEvent.ResponseDone)
    }

    @Test
    fun `coordinator injects short trigger audio instead of full caller intro`() {
        val localPlayed = mutableListOf<ShortArray>()
        val remotePlayed = mutableListOf<ShortArray>()
        val modelSent = mutableListOf<ShortArray>()
        val coordinator = AssistantTranslationIntroCoordinator(
            spec = AssistantTranslationIntroSpec(
                callerLanguage = "zh-CN",
                calleeLanguage = "en-US",
                provider = "qwen",
                traceId = "trace-1"
            ),
            callbacks = AssistantTranslationIntroCallbacks(
                playLocalFrame = { localPlayed += it },
                playRemoteFrames = { remotePlayed += it },
                sendModelLocalFrame = { modelSent += it },
                isCallActive = { true },
                onFailure = { throw AssertionError(it) }
            ),
            gate = AssistantTranslationIntroGate(),
            loadFrames = { language ->
                if (language.startsWith("zh")) {
                    List(4) { ShortArray(320) { 1 } }
                } else {
                    List(3) { ShortArray(320) { 2 } }
                }
            },
            loadTriggerFrames = { listOf(ShortArray(320) { 9 }) },
            sleeper = {},
            launcher = { task ->
                task()
                AssistantTranslationIntroTask {}
            },
            logger = {}
        )

        coordinator.markModelReady()
        assertTrue(coordinator.start())

        assertEquals(4, localPlayed.size)
        assertEquals(4, remotePlayed.size)
        assertTrue(remotePlayed.take(3).all { frame -> frame.all { it == 2.toShort() } })
        assertTrue(remotePlayed.last().all { it == 0.toShort() })
        assertEquals(1 + AssistantTranslationIntroAudio.TailSilenceFrames, modelSent.size)
        assertTrue(modelSent.first().all { it == 9.toShort() })
        assertTrue(modelSent.drop(1).all { frame -> frame.all { it == 0.toShort() } })
    }

    @Test
    fun `coordinator keeps shorter remote intro alive until local intro completes`() {
        val remotePlayed = mutableListOf<ShortArray>()
        val coordinator = AssistantTranslationIntroCoordinator(
            spec = AssistantTranslationIntroSpec(
                callerLanguage = "zh-CN",
                calleeLanguage = "en-US",
                provider = "qwen",
                traceId = "trace-aligned"
            ),
            callbacks = AssistantTranslationIntroCallbacks(
                playLocalFrame = {},
                playRemoteFrames = { remotePlayed += it },
                sendModelLocalFrame = {},
                isCallActive = { true },
                onFailure = { throw AssertionError(it) }
            ),
            gate = AssistantTranslationIntroGate(),
            loadFrames = { language ->
                if (language.startsWith("zh")) {
                    List(4) { ShortArray(320) { 1 } }
                } else {
                    List(2) { ShortArray(320) { 2 } }
                }
            },
            loadTriggerFrames = { listOf(ShortArray(320) { 9 }) },
            sleeper = {},
            launcher = { task ->
                task()
                AssistantTranslationIntroTask {}
            },
            logger = {}
        )

        coordinator.markModelReady()
        assertTrue(coordinator.start())

        assertEquals(4, remotePlayed.size)
        assertTrue(remotePlayed.take(2).all { frame -> frame.all { it == 2.toShort() } })
        assertTrue(remotePlayed.drop(2).all { frame -> frame.all { it == 0.toShort() } })
    }

    @Test
    fun `english intro asset remains the complete user supplied recording`() {
        val wav = rawSourceFile("translation_intro_en.wav").readBytes()
        val frames = AssistantTranslationIntroAudio.frames(wav)
        val filtered = AssistantTranslationIntroAudio.suppressLongQuietIntervals(frames)

        assertEquals(168, frames.size)
        assertEquals(168, filtered.size)
        assertTrue(filtered.subList(75, 100).all { frame -> frame.all { it == 0.toShort() } })
        assertTrue(
            "the complete second sentence must remain audible",
            filtered.drop(107).any { frame ->
                frame.maxOf { kotlin.math.abs(it.toInt()) } > 500
            }
        )
        assertEquals(
            "1c5058e7a69f297d96c1903d396468d3a30f3e82d1e48be8d5a2d15915054857",
            MessageDigest.getInstance("SHA-256")
                .digest(wav)
                .joinToString("") { "%02x".format(it) }
        )
    }

    @Test
    fun `long quiet interval is silenced without removing surrounding speech`() {
        val leadingSpeech = ShortArray(320) { 2_000 }
        val trailingSpeech = ShortArray(320) { -2_000 }
        val frames = listOf(leadingSpeech) +
            List(12) { ShortArray(320) { 8 } } +
            listOf(trailingSpeech)

        val filtered = AssistantTranslationIntroAudio.suppressLongQuietIntervals(frames)

        assertEquals(frames.size, filtered.size)
        assertTrue(filtered.first().all { it == 2_000.toShort() })
        assertTrue(filtered.last().all { it == (-2_000).toShort() })
        assertTrue(filtered.subList(1, 13).all { frame -> frame.all { it == 0.toShort() } })
    }

    @Test
    fun `remote playout sends pre silence before intro frames`() {
        val sent = Collections.synchronizedList(mutableListOf<ShortArray>())
        val playout = AssistantTranslationIntroRemotePlayout(
            traceId = "trace-remote",
            outputFrame = { sent += it.copyOf() },
            onFailure = { throw AssertionError(it) },
            logger = {}
        )

        playout.start()
        assertTrue(playout.enqueue(ShortArray(320) { 7 }))
        assertTrue(playout.enqueue(ShortArray(320) { 8 }))
        playout.finishAndAwait()

        assertEquals(12, sent.size)
        assertTrue(sent.take(10).all { frame -> frame.all { it == 0.toShort() } })
        assertTrue(sent[10].all { it == 7.toShort() })
        assertTrue(sent[11].all { it == 8.toShort() })
    }

    @Test
    fun `intro policy keeps normal calls disabled`() {
        assertTrue(AssistantTranslationConnectPromptPolicy.isEnabled(AssistantCallMode.TRANSLATION))
        assertFalse(AssistantTranslationConnectPromptPolicy.isEnabled(AssistantCallMode.NORMAL))
    }

    @Test
    fun `pure original gain covers both directions but bypasses intro playout`() {
        val bridge = sourceFile("AndroidSipMediaBridge.kt").readText(Charsets.UTF_8)

        assertEquals(
            2,
            "pureOriginalGain = originalAudioPureGain".toRegex()
                .findAll(bridge)
                .count()
        )
        assertTrue(bridge.contains("AssistantOriginalAudioGainCurve.gain("))
        val introCallbacks = bridge
            .substringAfter("callbacks = AssistantTranslationIntroCallbacks(")
            .substringBefore("gate = translationIntroGate")
        assertTrue(introCallbacks.contains("playLocalFrame = ::playPcm16k"))
        assertTrue(
            introCallbacks.contains(
                "playRemoteFrames = translationIntroRemotePlayback::play"
            )
        )
        assertFalse(introCallbacks.contains("MixPlayout"))
        assertFalse(introCallbacks.contains("originalAudioVolumePercent"))
    }

    @Test
    fun `sip bridge binds qwen response boundary to the intro coordinator`() {
        val bridge = sourceFile("AndroidSipMediaBridge.kt").readText(Charsets.UTF_8)

        assertTrue(bridge.contains("translation.setIntroTriggerResponseListener"))
        assertTrue(bridge.contains("coordinator?.markModelTriggerResponseDone()"))
        assertTrue(bridge.contains("expectTriggerResponseBoundary = responseBoundarySupported"))
    }

    private fun sourceFile(name: String): File = listOf(
        File("src/main/java/com/vvtech/aiassistant/callengine/$name"),
        File("android/app/src/main/java/com/vvtech/aiassistant/callengine/$name")
    ).first { it.exists() }

    private fun rawSourceFile(name: String): File = listOf(
        File("src/main/res/raw/$name"),
        File("android/app/src/main/res/raw/$name")
    ).first { it.exists() }
}
