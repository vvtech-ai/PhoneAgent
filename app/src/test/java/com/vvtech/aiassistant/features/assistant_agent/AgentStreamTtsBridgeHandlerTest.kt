package com.vvtech.aiassistant.features.assistant_agent

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamTtsBridgeHandlerTest {
    @Test
    fun voiceDeltaFeedsAgentTextDelta() {
        val harness = Harness(voiceMode = true)

        harness.handler.onDelta("hello")

        assertEquals(listOf("delta:hello"), harness.events)
    }

    @Test
    fun nonVoiceAndEmptyTextDoNotFeedTts() {
        val harness = Harness(voiceMode = false)

        harness.handler.onDelta("hello")
        harness.handler.onSignal("hello")
        harness.handler.onFlush()

        assertTrue(harness.events.isEmpty())

        val emptyHarness = Harness(voiceMode = true)
        emptyHarness.handler.onDelta("")
        emptyHarness.handler.onSignal("   ")

        assertTrue(emptyHarness.events.isEmpty())
    }

    @Test
    fun suppressedAudioSuspendsWithOriginalReasons() {
        val harness = Harness(voiceMode = true, suppressed = true)

        harness.handler.onDelta("delta")
        harness.handler.onSignal("signal")
        harness.handler.onFlush()

        assertEquals(
            listOf(
                "suspend:agent_stream_delta",
                "gate:maybeTtsSignal_suppressed",
                "suspend:agent_signal_text",
                "suspend:agent_tts_flush"
            ),
            harness.events
        )
    }

    @Test
    fun signalExceptionIsSwallowed() {
        val harness = Harness(voiceMode = true, signalThrows = true)

        harness.handler.onSignal("signal")

        assertEquals(listOf("signal:signal"), harness.events)
    }

    @Test
    fun voiceFlushCallsAgentTtsFlush() {
        val harness = Harness(voiceMode = true)

        harness.handler.onFlush()

        assertEquals(listOf("flush"), harness.events)
    }

    @Test
    fun agentStreamHandlerDelegatesTtsBridge() {
        val agentStreamHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val responseGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val ttsBridgeHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamTtsBridgeHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(agentStreamHandler.contains("AgentStreamTtsBridgeHandler("))
        assertTrue(agentStreamHandler.contains("maybeTtsDelta = ttsBridgeHandler::onDelta"))
        assertTrue(agentStreamHandler.contains("maybeTtsSignal = ttsBridgeHandler::onSignal"))
        assertTrue(responseGraph.contains("maybeTtsFlush = ttsBridgeHandler::onFlush"))
        assertFalse(agentStreamHandler.contains("private fun maybeTtsDelta("))
        assertFalse(agentStreamHandler.contains("private fun maybeTtsSignal("))
        assertFalse(agentStreamHandler.contains("private fun maybeTtsFlush("))
        assertFalse(agentStreamHandler.contains("private fun isCallDialogAudioSuppressed"))
        assertFalse(agentStreamHandler.contains("val callAudioSuppressed ="))
        assertFalse(agentStreamHandler.contains("viewModel.voiceDuplexCoordinator.feedAgentSignalText(text)"))
        assertFalse(agentStreamHandler.contains("viewModel.voiceDuplexCoordinator.flushAgentTts()"))

        assertTrue(ttsBridgeHandler.contains("TTS_STREAM_DELTA_RECEIVED"))
        assertTrue(ttsBridgeHandler.contains("maybeTtsSignal_suppressed"))
        assertTrue(ttsBridgeHandler.contains("agent_stream_delta"))
        assertTrue(ttsBridgeHandler.contains("agent_signal_text"))
        assertTrue(ttsBridgeHandler.contains("agent_tts_flush"))
        assertFalse(ttsBridgeHandler.contains("AssistantViewModel"))
        assertFalse(ttsBridgeHandler.contains("AssistantRepository"))
    }

    private class Harness(
        private val voiceMode: Boolean,
        private val suppressed: Boolean = false,
        private val signalThrows: Boolean = false
    ) {
        val events = mutableListOf<String>()
        val handler = AgentStreamTtsBridgeHandler(
            runtime = AgentStreamTtsBridgeRuntime(
                isVoiceMode = { voiceMode },
                isCallDialogAudioSuppressed = { suppressed },
                outboundCallAudioGateSnapshot = { "snapshot" },
                previewText = { it?.trim().orEmpty() }
            ),
            callbacks = AgentStreamTtsBridgeCallbacks(
                feedAgentTextDelta = { events += "delta:$it" },
                feedAgentSignalText = {
                    events += "signal:$it"
                    if (signalThrows) error("boom")
                },
                flushAgentTts = { events += "flush" },
                suspendDialogAudioForCall = { events += "suspend:$it" },
                logOutboundCallAudioGate = { events += "gate:$it" }
            )
        )
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
