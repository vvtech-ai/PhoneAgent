package com.vvtech.aiassistant.data.repository.timeline

import android.app.Application
import com.google.gson.JsonParser
import com.vvtech.aiassistant.data.local.timeline.SQLiteTimelineCacheDao
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheDatabase
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheFailpoint
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheStore
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineApi
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelinePageDto
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.ArrayDeque
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class ConversationTimelineRepositoryTest {
    private val context = RuntimeEnvironment.getApplication()
    private val stores = mutableListOf<Pair<TimelineCacheStore, String>>()

    @After
    fun cleanUp() = stores.forEach { (_, name) -> context.deleteDatabase(name) }

    @Test
    fun repeatedRestPageIsIdempotentAndProjectsOnlyCachedFacts() = runBlocking {
        val remote = QueueRemote(mapOf(null to listOf(page(1, 1)), 1L to listOf(page(1, 1))))
        val repository = repository(remote)

        val first = repository.sync("account-a", "session-1")
        val repeated = repository.sync("account-a", "session-1")

        assertEquals(listOf(1L), first.events.map { it.sequence })
        assertEquals(listOf(1L), repeated.events.map { it.sequence })
        assertEquals(listOf("ledger:event-1"), repeated.timeline.items.map { it.itemId })
    }

    @Test
    fun sequenceGapClearsProjectionAndRebuildsFromFullTimeline() = runBlocking {
        val logger = RecordingTimelineSyncLogger()
        val remote = QueueRemote(mapOf(
            null to listOf(page(1, 1), page(3, 3, 1, 2, 3)),
            1L to listOf(page(3, 3, 3)),
        ))
        val repository = repository(remote, logger)

        repository.sync("account-a", "session-1")
        val rebuilt = repository.sync("account-a", "session-1")

        assertEquals(listOf(1L, 2L, 3L), rebuilt.events.map { it.sequence })
        assertEquals(listOf(1L, 2L, 3L), rebuilt.timeline.items.map { it.ledgerSequence })
        assertTrue(logger.events.any {
            it.eventName == TimelineSyncLogEventName.GapResync &&
                it.result == TimelineSyncLogResult.Detected &&
                it.reason == TimelineSyncLogReason.SequenceGap
        })
        assertTrue(logger.events.any {
            it.result == TimelineSyncLogResult.Started &&
                it.reason == TimelineSyncLogReason.FullResyncStarted
        })
        assertTrue(logger.events.any {
            it.result == TimelineSyncLogResult.Success &&
                it.reason == TimelineSyncLogReason.FullResyncCompleted
        })
    }

    @Test
    fun syncStartSuccessAndUnknownSchemaAreStructured() = runBlocking {
        val logger = RecordingTimelineSyncLogger()
        val unknownSchemaPage = page(1, 1).copy(events = listOf(event(1).copy(schemaVersion = 2)))
        val repository = repository(QueueRemote(mapOf(null to listOf(unknownSchemaPage))), logger)

        repository.sync("account-a", "session-1")

        assertTrue(logger.events.any {
            it.result == TimelineSyncLogResult.Started && it.reason == TimelineSyncLogReason.SyncRequested
        })
        assertTrue(logger.events.any {
            it.result == TimelineSyncLogResult.Success && it.reason == TimelineSyncLogReason.PageSynced
        })
        assertTrue(logger.events.any {
            it.result == TimelineSyncLogResult.Warning &&
                it.reason == TimelineSyncLogReason.UnknownSchemaVersion &&
                it.schemaVersion == 2
        })
    }

    @Test
    fun cacheWriteFailureUsesStableReasonWithoutExceptionPayload() = runBlocking {
        val logger = RecordingTimelineSyncLogger()
        val name = "timeline-repository-failure-${System.nanoTime()}.db"
        val store = TimelineCacheStore(
            SQLiteTimelineCacheDao(
                TimelineCacheDatabase(context, name),
                TimelineCacheFailpoint { error("transcript=secret phone=13800138000 token=raw") },
            ),
        )
        stores += store to name
        val repository = ConversationTimelineRepository(
            QueueRemote(mapOf(null to listOf(page(1, 1)))),
            store,
            logger,
        )

        try {
            repository.sync("account-a-sensitive", "session-1")
            fail("expected cache failure")
        } catch (_: IllegalStateException) {
            // Expected failpoint; only the stable classification may reach the logger.
        }

        val failure = logger.events.single { it.result == TimelineSyncLogResult.Failure }
        assertEquals(TimelineSyncLogReason.CacheWriteFailed, failure.reason)
        assertEquals("session-1", failure.sessionId)
    }

    @Test
    fun localAheadAndEmptyRemotePageProduceAnEmptyRebuiltCache() = runBlocking {
        val remote = QueueRemote(mapOf(
            null to listOf(page(head = 0)),
            1L to listOf(page(head = 0)),
        ))
        val repository = repository(remote)
        val store = stores.single().first
        store.writePage("account-a", page(1, 1))

        val rebuilt = repository.sync("account-a", "session-1")

        assertTrue(rebuilt.events.isEmpty())
        assertEquals(0L, rebuilt.ledgerHeadSequence)
    }

    @Test
    fun emptyRemoteHeadForUncachedSessionIsExplicitLegacyNoLedger() = runBlocking {
        val repository = repository(QueueRemote(mapOf(null to listOf(page(head = 0)))))

        try {
            repository.sync("account-a", "session-1")
            fail("expected legacy no-ledger classification")
        } catch (_: TimelineLegacyNoLedgerException) {
            // The restore boundary may use its read-only legacy view exactly for this signal.
        }
    }

    @Test
    fun transportFailureIsExplicitTimelineUnavailable() = runBlocking {
        val source = RetrofitConversationTimelineRemoteSource(object : ConversationTimelineApi {
            override suspend fun getTimeline(sessionId: String, afterSequence: Long?, limit: Int?): ConversationTimelinePageDto {
                throw IOException("offline")
            }
        })

        try {
            source.load("session-1", null, 1)
            fail("expected unavailable classification")
        } catch (_: TimelineUnavailableException) {
            // Expected: restore may use its one read-only compatibility fallback.
        }
    }

    @Test
    fun cacheRemainsAccountScopedWhenSameSessionIsSynced() = runBlocking {
        val remote = QueueRemote(mapOf(null to listOf(page(1, 1), page(1, 1))))
        val repository = repository(remote)

        repository.sync("account-a", "session-1")
        repository.sync("account-b", "session-1")

        val store = stores.single().first
        assertEquals("event-1", store.read("account-a", "session-1")!!.events.single().eventId)
        assertEquals("event-1", store.read("account-b", "session-1")!!.events.single().eventId)
    }

    @Test
    fun repeatedCommittedSseEventDoesNotDuplicateCacheOrProjection() = runBlocking {
        val repository = repository(QueueRemote(mapOf(null to listOf(page(1, 1)))))

        repository.sync("account-a", "session-1")
        repository.mergeCommittedEvent("account-a", event(2))
        val repeated = repository.mergeCommittedEvent("account-a", event(2))

        assertEquals(listOf(1L, 2L), repeated.events.map { it.sequence })
        assertEquals(listOf(1L, 2L), repeated.timeline.items.map { it.ledgerSequence })
    }

    @Test
    fun restDuplicateAfterCommittedSseKeepsOneDurableItem() = runBlocking {
        val remote = QueueRemote(mapOf(
            null to listOf(page(1, 1)),
            2L to listOf(page(2, 1, 2)),
        ))
        val repository = repository(remote)

        repository.sync("account-a", "session-1")
        repository.mergeCommittedEvent("account-a", event(2))
        val restored = repository.sync("account-a", "session-1")

        assertEquals(listOf(1L, 2L), restored.events.map { it.sequence })
        assertEquals(listOf("event-1", "event-2"), restored.events.map { it.eventId })
    }

    @Test
    fun clearedCacheRebuildsOnlyFromRestFacts() = runBlocking {
        val remote = QueueRemote(mapOf(null to listOf(page(1, 1), page(2, 1, 2))))
        val repository = repository(remote)
        val store = stores.single().first

        repository.sync("account-a", "session-1")
        store.clear("account-a", "session-1")
        val rebuilt = repository.sync("account-a", "session-1")

        assertEquals(listOf(1L, 2L), rebuilt.events.map { it.sequence })
        assertEquals(listOf(1L, 2L), rebuilt.timeline.items.map { it.ledgerSequence })
    }

    @Test
    fun staleRedactedShowOptionsCacheIsRefreshedFromFullTimeline() = runBlocking {
        val logger = RecordingTimelineSyncLogger()
        val name = "timeline-repository-options-${System.nanoTime()}.db"
        val store = TimelineCacheStore(SQLiteTimelineCacheDao(TimelineCacheDatabase(context, name)))
        stores += store to name
        store.writePage(
            "account-a",
            page(1, 1).copy(events = listOf(showOptionsEvent(displayPayloadVersion = null))),
        )
        val refreshedPage = page(1, 1).copy(
            events = listOf(showOptionsEvent(displayPayloadVersion = 1)),
        )
        val repository = ConversationTimelineRepository(
            QueueRemote(mapOf(null to listOf(refreshedPage))),
            store,
            logger,
        )

        val restored = repository.sync("account-a", "session-1")

        assertTrue(restored.timeline.items.single().payload is
            com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload.AssistantMessage)
        assertTrue(logger.events.any {
            it.eventName == TimelineSyncLogEventName.GapResync &&
                it.result == TimelineSyncLogResult.Detected &&
                it.reason == TimelineSyncLogReason.DisplayPayloadUpgrade
        })
    }

    @Test
    fun staleRedactedInteractivePromptCacheIsRefreshedFromFullTimeline() = runBlocking {
        val logger = RecordingTimelineSyncLogger()
        val name = "timeline-repository-interactive-${System.nanoTime()}.db"
        val store = TimelineCacheStore(SQLiteTimelineCacheDao(TimelineCacheDatabase(context, name)))
        stores += store to name
        store.writePage(
            "account-a",
            page(1, 1).copy(events = listOf(askUserEvent(displayPayloadVersion = null))),
        )
        val refreshedPage = page(1, 1).copy(
            events = listOf(askUserEvent(displayPayloadVersion = 1)),
        )
        val repository = ConversationTimelineRepository(
            QueueRemote(mapOf(null to listOf(refreshedPage))),
            store,
            logger,
        )

        val restored = repository.sync("account-a", "session-1")

        val prompt = restored.timeline.items.single().payload as
            com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload.AssistantMessage
        assertEquals("补充信息\n· 几点出发？", prompt.text)
        assertTrue(logger.events.any {
            it.eventName == TimelineSyncLogEventName.GapResync &&
                it.result == TimelineSyncLogResult.Detected &&
                it.reason == TimelineSyncLogReason.DisplayPayloadUpgrade
        })
    }

    private fun repository(
        remote: ConversationTimelineRemoteSource,
        logger: TimelineSyncLogger = AppFileTimelineSyncLogger(),
    ): ConversationTimelineRepository {
        val name = "timeline-repository-${System.nanoTime()}.db"
        val store = TimelineCacheStore(SQLiteTimelineCacheDao(TimelineCacheDatabase(context, name)))
        stores += store to name
        return ConversationTimelineRepository(remote, store, logger)
    }

    private fun page(
        head: Long,
        vararg sequences: Long,
    ): ConversationTimelinePage = ConversationTimelinePage(
        sessionId = "session-1", schemaVersion = 1, ledgerHeadSequence = head,
        requestedAfterSequence = null, firstSequence = sequences.firstOrNull(), lastSequence = sequences.lastOrNull(),
        nextAfterSequence = sequences.lastOrNull(), hasMore = false,
        projection = ConversationTimelineProjection("ACTIVE", true, false, "COMPLETE", head),
        events = sequences.map(::event),
    )

    private fun event(sequence: Long): ConversationLedgerEvent = ConversationLedgerEvent(
        eventId = "event-$sequence", sessionId = "session-1", sequence = sequence,
        type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.USER_TURN_ACCEPTED),
        schemaVersion = 1, idempotencyKey = "key-$sequence", occurredAt = "2026-07-21T00:00:00Z",
        committedAt = "2026-07-21T00:00:01Z", payload = JsonParser().parse("{\"text\":\"event-$sequence\"}").asJsonObject,
    )

    private fun showOptionsEvent(displayPayloadVersion: Int?): ConversationLedgerEvent {
        val versionField = displayPayloadVersion?.let { ",\"displayPayloadVersion\":$it" }.orEmpty()
        return event(1).copy(
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.TOOL_REQUESTED),
            payload = JsonParser().parse(
                """
                {
                  "toolName":"showOptions"$versionField,
                  "arguments":{
                    "title":"搜到的结果",
                    "optionsJson":[{"id":"one","label":"测试餐厅"}]
                  }
                }
                """.trimIndent()
            ).asJsonObject,
        )
    }

    private fun askUserEvent(displayPayloadVersion: Int?): ConversationLedgerEvent {
        val versionField = displayPayloadVersion?.let { ",\"displayPayloadVersion\":$it" }.orEmpty()
        return event(1).copy(
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.TOOL_REQUESTED),
            payload = JsonParser().parse(
                """
                {
                  "toolName":"askUser"$versionField,
                  "arguments":{
                    "title":"补充信息",
                    "questionsJson":[{"prompt":"几点出发？"}]
                  }
                }
                """.trimIndent()
            ).asJsonObject,
        )
    }

    private class QueueRemote(pages: Map<Long?, List<ConversationTimelinePage>>) : ConversationTimelineRemoteSource {
        private val pages = pages.mapValues { ArrayDeque(it.value) }.toMutableMap()

        override suspend fun load(sessionId: String, afterSequence: Long?, limit: Int): ConversationTimelinePage =
            requireNotNull(pages[afterSequence]) { "unexpected cursor $afterSequence" }.removeFirst()
    }

    private class RecordingTimelineSyncLogger : TimelineSyncLogger {
        val events = mutableListOf<TimelineSyncLogEvent>()
        override fun record(event: TimelineSyncLogEvent) {
            events += event
        }
    }
}
