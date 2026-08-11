package com.vvtech.aiassistant.features.assistant_voice_clone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneRuntimeLoggerTest {
    @Test
    fun correlationRefsAreStableWithoutExposingRawIdentifiers() {
        val event = voiceCloneRuntimeEvent(
            eventType = "VOICE_CLONE_TEST",
            attemptId = "attempt-sensitive-value",
            collectionId = "collection-sensitive-value",
            provider = "aliyun_mfvc",
            stateBefore = "INITIATED",
            stateAfter = "PASS"
        )

        assertEquals("3f5174db3efa", voiceCloneLogRef("attempt-sensitive-value"))
        assertEquals(voiceCloneLogRef("attempt-sensitive-value"), event.traceId)
        assertEquals(
            voiceCloneLogRef("collection-sensitive-value"),
            event.attributes["collectionRef"]
        )
        assertNotEquals("attempt-sensitive-value", event.traceId)
        assertFalse(event.attributes.values.contains("collection-sensitive-value"))
        assertTrue(event.traceId!!.matches(Regex("^[a-f0-9]{12}$")))
    }
}
