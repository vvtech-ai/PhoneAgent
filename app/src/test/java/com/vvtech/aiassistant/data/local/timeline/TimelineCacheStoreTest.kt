package com.vvtech.aiassistant.data.local.timeline

import android.app.Application
import com.google.gson.JsonParser
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class TimelineCacheStoreTest {
    private val context = RuntimeEnvironment.getApplication()
    private val databaseName = "timeline-cache-${System.nanoTime()}.db"
    private val database = TimelineCacheDatabase(context, databaseName)

    @After
    fun tearDown() {
        database.close()
        context.deleteDatabase(databaseName)
    }

    @Test
    fun repeatedPageIsIdempotentAndCursorIsReplacedAtomically() {
        val store = TimelineCacheStore(SQLiteTimelineCacheDao(database))
        val first = page(event(1, "event-1"), head = 1, cursor = 1)

        store.writePage("account-a", first)
        store.writePage("account-a", first)
        store.writePage("account-a", page(event(2, "event-2"), head = 2, cursor = 2))

        val cached = requireNotNull(store.read("account-a", "session-1"))
        assertEquals(listOf(1L, 2L), cached.events.map { it.sequence })
        assertEquals(2L, cached.nextAfterSequence)
    }

    @Test
    fun accountAndSessionKeysAreIsolated() {
        val store = TimelineCacheStore(SQLiteTimelineCacheDao(database))
        store.writePage("account-a", page(event(1, "event-a"), head = 1, cursor = 1))
        store.writePage("account-b", page(event(1, "event-b"), head = 1, cursor = 1))

        assertEquals("event-a", store.read("account-a", "session-1")?.events?.single()?.eventId)
        assertEquals("event-b", store.read("account-b", "session-1")?.events?.single()?.eventId)
        assertNull(store.read("account-c", "session-1"))
    }

    @Test
    fun failpointRollsBackEventsAndCursorTogether() {
        val store = TimelineCacheStore(SQLiteTimelineCacheDao(database, TimelineCacheFailpoint {
            throw IllegalStateException("injected write interruption")
        }))

        runCatching { store.writePage("account-a", page(event(1, "event-1"), head = 1, cursor = 1)) }
            .onSuccess { throw AssertionError("expected failpoint") }

        assertNull(store.read("account-a", "session-1"))
        assertTrue(database.readableDatabase.query(
            "timeline_event_cache", arrayOf("event_id"), null, null, null, null, null,
        ).use { it.count == 0 })
    }

    private fun page(event: ConversationLedgerEvent, head: Long, cursor: Long) = ConversationTimelinePage(
        sessionId = "session-1", schemaVersion = 1, ledgerHeadSequence = head,
        requestedAfterSequence = cursor - 1, firstSequence = event.sequence, lastSequence = event.sequence,
        nextAfterSequence = cursor, hasMore = false,
        projection = ConversationTimelineProjection("ACTIVE", true, false, "COMPLETE", cursor),
        events = listOf(event),
    )

    private fun event(sequence: Int, eventId: String) = ConversationLedgerEvent(
        eventId = eventId, sessionId = "session-1", sequence = sequence.toLong(),
        type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.USER_TURN_ACCEPTED),
        schemaVersion = 1, idempotencyKey = "key-$eventId",
        occurredAt = "2026-07-21T00:00:00Z", committedAt = "2026-07-21T00:00:01Z",
        payload = JsonParser().parse("{\"text\":\"hello\"}").asJsonObject,
    )
}
