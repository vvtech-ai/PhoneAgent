package com.vvtech.aiassistant.data.repository.timeline

import android.app.Application
import com.google.gson.JsonParser
import com.vvtech.aiassistant.data.local.timeline.SQLiteTimelineCacheDao
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheDatabase
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheStore
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class ConversationTimelineLifecycleAcceptanceTest {
    private val context = RuntimeEnvironment.getApplication()
    private val databases = mutableListOf<TimelineCacheDatabase>()
    private val databaseNames = mutableListOf<String>()

    @After
    fun cleanUp() {
        databases.forEach(TimelineCacheDatabase::close)
        databaseNames.forEach(context::deleteDatabase)
    }

    @Test
    fun lifecycleParityWithLargeHistoryAndFourAttempts() = runBlocking {
        val server = MutableTimelineRemote(largeConversationFixture())
        val persistentName = newDatabaseName("p")
        val persistentStore = store(persistentName)
        val onlineRepository = ConversationTimelineRepository(server, persistentStore)

        val online = onlineRepository.sync(ACCOUNT_ID, SESSION_ID)
        val reenteredRepository = ConversationTimelineRepository(server, persistentStore)
        val reentered = reenteredRepository.sync(ACCOUNT_ID, SESSION_ID)
        val noCacheDevice = repository(newDatabaseName("f"), server).sync(ACCOUNT_ID, SESSION_ID)

        assertEquivalent(online, reentered)
        assertEquivalent(online, noCacheDevice)
        assertEquals(52, online.timeline.items.count {
            it.payload is ConversationTimelinePayload.UserMessage ||
                it.payload is ConversationTimelinePayload.AssistantMessage
        })
        val callReceipts = online.timeline.items.mapNotNull {
            it.payload as? ConversationTimelinePayload.SingleCallReceipt
        }
        assertEquals(listOf("attempt-1", "attempt-2", "attempt-3", "attempt-4"), callReceipts.map { it.callAttemptId })
        assertEquals((1..4).map { "AI：第${it}次外呼\n对方：第${it}次答复" }, callReceipts.map { it.receipt.transcript })

        val durableBeforeContinuation = reentered.timeline.items
        server.append(messageEvent(61, StableConversationLedgerEventType.USER_TURN_ACCEPTED, "继续追问"))
        server.append(messageEvent(62, StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED, "继续回答"))

        val continued = reenteredRepository.sync(ACCOUNT_ID, SESSION_ID)
        val relaunchedWithoutCache = repository(newDatabaseName("c"), server)
            .sync(ACCOUNT_ID, SESSION_ID)

        assertEquals(durableBeforeContinuation, continued.timeline.items.take(durableBeforeContinuation.size))
        assertEquivalent(continued, relaunchedWithoutCache)
        assertEquals(listOf("继续追问", "继续回答"), continued.timeline.items.takeLast(2).map {
            when (val payload = it.payload) {
                is ConversationTimelinePayload.UserMessage -> payload.text
                is ConversationTimelinePayload.AssistantMessage -> payload.text
                else -> error("unexpected continuation payload $payload")
            }
        })
    }

    private fun repository(
        name: String,
        remote: ConversationTimelineRemoteSource,
    ): ConversationTimelineRepository = ConversationTimelineRepository(remote, store(name))

    private fun store(name: String): TimelineCacheStore {
        val database = TimelineCacheDatabase(context, name)
        databases += database
        return TimelineCacheStore(SQLiteTimelineCacheDao(database))
    }

    private fun newDatabaseName(label: String): String =
        "tl-$label-${System.nanoTime()}.db".also(databaseNames::add)

    private fun largeConversationFixture(): List<ConversationLedgerEvent> {
        val messages = (1L..52L).map { sequence ->
            val type = if (sequence % 2L == 1L) {
                StableConversationLedgerEventType.USER_TURN_ACCEPTED
            } else {
                StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED
            }
            messageEvent(sequence, type, "message-$sequence")
        }
        val calls = (1L..4L).flatMap { attempt ->
            val requestSequence = 51L + attempt * 2L
            listOf(
                callEvent(requestSequence, attempt, StableConversationLedgerEventType.CALL_REQUESTED),
                callEvent(requestSequence + 1L, attempt, StableConversationLedgerEventType.CALL_COMPLETED),
            )
        }
        return messages + calls
    }

    private fun messageEvent(sequence: Long, type: StableConversationLedgerEventType, text: String) =
        event(sequence, type, "{\"text\":\"$text\"}")

    private fun callEvent(sequence: Long, attempt: Long, type: StableConversationLedgerEventType) =
        event(
            sequence,
            type,
            if (type == StableConversationLedgerEventType.CALL_REQUESTED) {
                "{\"recipientRef\":\"目标-$attempt\"}"
            } else {
                "{\"resultCode\":\"COMPLETED\",\"summary\":\"第${attempt}次完成\"," +
                    "\"transcript\":\"AI：第${attempt}次外呼\\n对方：第${attempt}次答复\"}"
            },
        ).copy(taskId = TASK_ID, callAttemptId = "attempt-$attempt", callId = "call-$attempt")

    private fun event(sequence: Long, type: StableConversationLedgerEventType, payload: String) =
        ConversationLedgerEvent(
            eventId = "event-$sequence",
            sessionId = SESSION_ID,
            sequence = sequence,
            type = ConversationLedgerEventType.Known(type),
            schemaVersion = 1,
            idempotencyKey = "key-$sequence",
            occurredAt = "2026-07-21T00:00:00Z",
            committedAt = "2026-07-21T00:00:01Z",
            payload = JsonParser().parse(payload).asJsonObject,
        )

    private fun assertEquivalent(
        expected: ConversationTimelineSnapshot,
        actual: ConversationTimelineSnapshot,
    ) {
        assertEquals(expected.ledgerHeadSequence, actual.ledgerHeadSequence)
        assertEquals(expected.events, actual.events)
        assertEquals(expected.projection, actual.projection)
        assertEquals(expected.timeline, actual.timeline)
        assertTrue(actual.events.zipWithNext().all { (left, right) -> right.sequence == left.sequence + 1L })
    }

    private class MutableTimelineRemote(initial: List<ConversationLedgerEvent>) : ConversationTimelineRemoteSource {
        private val events = initial.toMutableList()

        fun append(event: ConversationLedgerEvent) {
            events += event
        }

        override suspend fun load(sessionId: String, afterSequence: Long?, limit: Int): ConversationTimelinePage {
            val pageEvents = events.filter { it.sequence > (afterSequence ?: 0L) }.take(limit)
            val head = events.maxOfOrNull(ConversationLedgerEvent::sequence) ?: 0L
            val cursor = pageEvents.lastOrNull()?.sequence ?: afterSequence
            return ConversationTimelinePage(
                sessionId = sessionId,
                schemaVersion = 1,
                ledgerHeadSequence = head,
                requestedAfterSequence = afterSequence,
                firstSequence = pageEvents.firstOrNull()?.sequence,
                lastSequence = pageEvents.lastOrNull()?.sequence,
                nextAfterSequence = cursor,
                hasMore = cursor != null && cursor < head,
                projection = ConversationTimelineProjection("ACTIVE", true, false, "LEDGER_NATIVE", head),
                events = pageEvents,
            )
        }
    }

    private companion object {
        const val ACCOUNT_ID = "account-a"
        const val SESSION_ID = "session-1"
        const val TASK_ID = "task-1"
    }
}
