package com.vvtech.aiassistant.features.translation_call.backend

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Base64
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackendRealtimeProtocolTest {
    @Test
    fun `parses base64 translated audio with server sequence`() {
        val pcm = byteArrayOf(1, 2, 3, 4)
        val message = BackendRealtimeProtocol.parseText(
            JSONObject()
                .put("event", "translated_audio")
                .put("audioFormat", "pcm16")
                .put("sampleRate", 24_000)
                .put("payload", Base64.getEncoder().encodeToString(pcm))
                .put("diagnostics", JSONObject().put("serverSequence", 18))
                .toString()
        )

        val audio = message.event as BackendRealtimeEvent.TranslatedAudio
        assertArrayEquals(pcm, audio.pcmLittleEndian)
        assertEquals(18L, audio.sequence)
    }

    @Test
    fun `parses binary translated audio header and pcm`() {
        val header = JSONObject()
            .put("event", "translated_audio")
            .put("callSessionId", "call-1")
            .put("sequence", 7)
            .put("sampleRate", 16_000)
            .toString()
            .toByteArray()
        val pcm = byteArrayOf(10, 11, 12, 13)
        val frame = ByteBuffer.allocate(4 + header.size + pcm.size)
            .order(ByteOrder.BIG_ENDIAN)
            .putInt(header.size)
            .put(header)
            .put(pcm)
            .array()

        val message = BackendRealtimeProtocol.parseBinary(frame)

        val audio = message.event as BackendRealtimeEvent.TranslatedAudio
        assertEquals("call-1", message.callSessionId)
        assertEquals(7L, audio.sequence)
        assertArrayEquals(pcm, audio.pcmLittleEndian)
    }

    @Test
    fun `parses ready transcript environment and terminal events`() {
        val ready = BackendRealtimeProtocol.parseText(
            """{"event":"realtime_ready","callSessionId":"call-1"}"""
        )
        val transcript = BackendRealtimeProtocol.parseText(
            """
            {
              "event":"transcript_delta",
              "callSessionId":"call-1",
              "segmentId":"seg-1",
              "sourceLeg":"user",
              "targetLeg":"merchant",
              "kind":"output",
              "text":"hello",
              "isFinal":true,
              "replace":true,
              "environment":{"version":3,"model":{"state":"available"}}
            }
            """.trimIndent()
        )
        val ended = BackendRealtimeProtocol.parseText(
            """{"event":"call_ended","reason":"remote_hangup"}"""
        )

        assertEquals(
            BackendRealtimeEvent.Ready.Kind.Realtime,
            (ready.event as BackendRealtimeEvent.Ready).kind
        )
        assertEquals(3L, transcript.environment?.version)
        assertTrue((transcript.event as BackendRealtimeEvent.TranscriptDelta).final)
        assertEquals("remote_hangup", (ended.event as BackendRealtimeEvent.CallEnded).reason)
    }

    @Test
    fun `keeps unknown event forward compatible`() {
        val message = BackendRealtimeProtocol.parseText(
            """{"event":"future_server_event","callSessionId":"call-1","token":"secret"}"""
        )

        assertEquals(
            "future_server_event",
            (message.event as BackendRealtimeEvent.Unknown).name
        )
    }

    @Test
    fun `rejects malformed binary headers and empty payloads`() {
        val oversized = ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN)
            .putInt(4097)
            .array()
        val header = """{"event":"translated_audio","sampleRate":16000}""".toByteArray()
        val emptyPayload = ByteBuffer.allocate(4 + header.size)
            .order(ByteOrder.BIG_ENDIAN)
            .putInt(header.size)
            .put(header)
            .array()

        assertTrue(runCatching { BackendRealtimeProtocol.parseBinary(oversized) }.isFailure)
        assertTrue(runCatching { BackendRealtimeProtocol.parseBinary(emptyPayload) }.isFailure)
    }
}
