package com.vvtech.aiassistant.data.remote.timeline

import com.google.gson.Gson
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationTimelineWireMapperTest {
    @Test
    fun sharedGoldenPageMapsWithoutExposingDto() {
        val dto = Gson().fromJson(golden("timeline-page.json"), ConversationTimelinePageDto::class.java)

        val page = ConversationTimelineWireMapper.toDomain(dto)

        assertEquals("session-23065", page.sessionId)
        assertEquals(4L, page.nextAfterSequence)
        assertEquals(4L, page.events.single().sequence)
        assertEquals("CALL_COMPLETED", page.events.single().type.wireName)
        assertEquals("embedded_sip", page.events.single().payload["provider"].asString)
    }

    @Test
    fun unknownWireTypeRetainsIdentityAndRawPayload() {
        val event = ConversationTimelineWireMapper.toDomain(ConversationTimelineEventDto(
            eventId = "future-1", sessionId = "session", sequence = Long.MAX_VALUE,
            eventType = "FUTURE_EVENT", schemaVersion = 9, idempotencyKey = "key",
            occurredAt = "2026-07-21T00:00:00Z", committedAt = "2026-07-21T00:00:01Z",
            payload = com.google.gson.JsonParser().parse("{\"opaque\":true}").asJsonObject,
        ))

        assertTrue(event.type is ConversationLedgerEventType.Unknown)
        assertEquals(Long.MAX_VALUE, event.sequence)
        assertTrue(event.payload["opaque"].asBoolean)
    }

    private fun golden(name: String): String = requireNotNull(
        javaClass.classLoader?.getResourceAsStream("conversation-history/v1/$name")
    ).bufferedReader().use { it.readText() }
}
