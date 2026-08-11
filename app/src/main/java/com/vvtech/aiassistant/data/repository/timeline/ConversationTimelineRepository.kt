package com.vvtech.aiassistant.data.repository.timeline

import com.vvtech.aiassistant.data.local.timeline.CachedTimelinePage
import com.vvtech.aiassistant.data.local.timeline.TimelineCacheStore
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import com.vvtech.aiassistant.features.assistant_timeline.ConversationLedgerTimelineReducer
import com.vvtech.aiassistant.features.assistant_timeline.InteractiveToolTimelineProjection
import com.vvtech.aiassistant.features.assistant_timeline.LedgerTimelineState
import com.vvtech.aiassistant.features.assistant_timeline.ShowOptionsTimelineProjection

/**
 * Owns cache synchronization only. Durable facts come from REST/SSE; this repository
 * never creates a timeline event or writes the legacy call-history store.
 */
class ConversationTimelineRepository(
    private val remote: ConversationTimelineRemoteSource,
    private val cache: TimelineCacheStore,
    private val logger: TimelineSyncLogger = AppFileTimelineSyncLogger(),
) {
    suspend fun sync(accountId: String, sessionId: String, pageSize: Int = DEFAULT_PAGE_SIZE): ConversationTimelineSnapshot {
        validateRequest(accountId, sessionId, pageSize)
        recordSync(sessionId, 0L, 0L, 0, TimelineSyncLogSource.Rest, TimelineSyncLogResult.Started, TimelineSyncLogReason.SyncRequested)
        val cached = readCache(accountId, sessionId, TimelineSyncLogSource.Rest)
        val cursor = cached.cursor()
        if (cached.requiresDisplayPayloadUpgrade()) {
            recordGap(
                sessionId,
                cursor,
                cached?.ledgerHeadSequence ?: cursor,
                TimelineSyncLogResult.Detected,
                TimelineSyncLogReason.DisplayPayloadUpgrade,
            )
            return fullResync(
                accountId,
                sessionId,
                pageSize,
                cursor,
                cached?.ledgerHeadSequence ?: cursor,
            )
        }
        val firstPage = remote.load(sessionId, cursor.takeIf { it > 0L }, pageSize).normalizedFor(sessionId)
        recordUnsupportedEvents(firstPage.events, TimelineSyncLogSource.Rest)
        if (cached == null && firstPage.ledgerHeadSequence == 0L && firstPage.events.isEmpty()) {
            throw TimelineLegacyNoLedgerException("timeline ledger is not available for this session")
        }
        if (cursor > firstPage.ledgerHeadSequence || cached.lastSequence() > firstPage.ledgerHeadSequence) {
            recordGap(sessionId, cursor, firstPage.ledgerHeadSequence, TimelineSyncLogResult.Detected, TimelineSyncLogReason.LocalAhead)
            return fullResync(accountId, sessionId, pageSize, cursor, firstPage.ledgerHeadSequence)
        }
        if (requiresResync(cached, cursor, firstPage)) {
            recordGap(sessionId, cursor, firstPage.ledgerHeadSequence, TimelineSyncLogResult.Detected, TimelineSyncLogReason.SequenceGap)
            return fullResync(accountId, sessionId, pageSize, cursor, firstPage.ledgerHeadSequence)
        }
        return persistRemaining(accountId, sessionId, pageSize, cached, firstPage)
    }

    /** Committed SSE uses the same event contract and follows the same idempotent cache path. */
    suspend fun mergeCommittedEvent(accountId: String, event: ConversationLedgerEvent): ConversationTimelineSnapshot {
        require(accountId.isNotBlank()) { "accountId is required" }
        recordSync(event.sessionId, 0L, event.sequence, 1, TimelineSyncLogSource.Sse, TimelineSyncLogResult.Started, TimelineSyncLogReason.SyncRequested)
        recordUnsupportedEvents(listOf(event), TimelineSyncLogSource.Sse)
        val cached = readCache(accountId, event.sessionId, TimelineSyncLogSource.Sse) ?: return sync(accountId, event.sessionId)
        val cursor = cached.cursor()
        if (event.sequence > cursor + 1) {
            recordGap(event.sessionId, cursor, event.sequence, TimelineSyncLogResult.Detected, TimelineSyncLogReason.SequenceGap, TimelineSyncLogSource.Sse)
            return fullResync(accountId, event.sessionId, DEFAULT_PAGE_SIZE, cursor, event.sequence)
        }
        if (event.sequence <= cursor) {
            val stored = cached.events.firstOrNull { it.sequence == event.sequence || it.eventId == event.eventId }
            if (stored != event) {
                recordGap(event.sessionId, cursor, event.sequence, TimelineSyncLogResult.Detected, TimelineSyncLogReason.DuplicateConflict, TimelineSyncLogSource.Sse)
                return fullResync(accountId, event.sessionId, DEFAULT_PAGE_SIZE, cursor, event.sequence)
            }
            recordSync(event.sessionId, cursor, cursor, 0, TimelineSyncLogSource.Sse, TimelineSyncLogResult.Success, TimelineSyncLogReason.DuplicateIgnored)
            return cached.snapshot()
        }
        writeCache(accountId, cached.pageWith(event), TimelineSyncLogSource.Sse)
        recordSync(event.sessionId, cursor, event.sequence, 1, TimelineSyncLogSource.Sse, TimelineSyncLogResult.Success, TimelineSyncLogReason.SseMerged)
        return requireNotNull(readCache(accountId, event.sessionId, TimelineSyncLogSource.Sse)).snapshot()
    }

    private suspend fun fullResync(
        accountId: String,
        sessionId: String,
        pageSize: Int,
        fromSequence: Long,
        toSequence: Long,
    ): ConversationTimelineSnapshot {
        recordGap(sessionId, fromSequence, toSequence, TimelineSyncLogResult.Started, TimelineSyncLogReason.FullResyncStarted)
        clearCache(accountId, sessionId)
        val first = remote.load(sessionId, null, pageSize).normalizedFor(sessionId)
        recordUnsupportedEvents(first.events, TimelineSyncLogSource.Rest)
        if (requiresResync(null, 0L, first)) throw TimelineSyncException("full resync returned a sequence gap")
        return persistRemaining(accountId, sessionId, pageSize, null, first).also { snapshot ->
            recordGap(sessionId, 0L, snapshot.ledgerHeadSequence, TimelineSyncLogResult.Success, TimelineSyncLogReason.FullResyncCompleted)
        }
    }

    private suspend fun persistRemaining(
        accountId: String,
        sessionId: String,
        pageSize: Int,
        initialCached: CachedTimelinePage?,
        initialPage: ConversationTimelinePage,
    ): ConversationTimelineSnapshot {
        var cached = initialCached
        var page = initialPage
        while (true) {
            if (page.events.isEmpty() && page.hasMore) throw TimelineSyncException("empty timeline page cannot advance cursor")
            writeCache(accountId, page, TimelineSyncLogSource.Rest)
            recordSync(sessionId, cached.cursor(), page.lastSequence ?: cached.cursor(), page.events.size, TimelineSyncLogSource.Rest, TimelineSyncLogResult.Success, TimelineSyncLogReason.PageSynced)
            cached = requireNotNull(readCache(accountId, sessionId, TimelineSyncLogSource.Rest))
            if (!page.hasMore) return cached.snapshot()
            val next = page.nextAfterSequence ?: throw TimelineSyncException("paged response lacks next cursor")
            page = remote.load(sessionId, next, pageSize).normalizedFor(sessionId)
            recordUnsupportedEvents(page.events, TimelineSyncLogSource.Rest)
            if (requiresResync(cached, next, page)) {
                recordGap(sessionId, next, page.ledgerHeadSequence, TimelineSyncLogResult.Detected, TimelineSyncLogReason.SequenceGap)
                return fullResync(accountId, sessionId, pageSize, next, page.ledgerHeadSequence)
            }
        }
    }

    private fun readCache(accountId: String, sessionId: String, source: TimelineSyncLogSource): CachedTimelinePage? =
        runCatching { cache.read(accountId, sessionId) }.getOrElse {
            recordSync(sessionId, 0L, 0L, 0, source, TimelineSyncLogResult.Failure, TimelineSyncLogReason.CacheReadFailed)
            throw it
        }

    private fun writeCache(accountId: String, page: ConversationTimelinePage, source: TimelineSyncLogSource) {
        runCatching { cache.writePage(accountId, page) }.getOrElse {
            recordSync(page.sessionId, page.requestedAfterSequence ?: 0L, page.lastSequence ?: 0L, page.events.size, source, TimelineSyncLogResult.Failure, TimelineSyncLogReason.CacheWriteFailed)
            throw it
        }
    }

    private fun clearCache(accountId: String, sessionId: String) {
        runCatching { cache.clear(accountId, sessionId) }.getOrElse {
            recordGap(sessionId, 0L, 0L, TimelineSyncLogResult.Failure, TimelineSyncLogReason.CacheClearFailed)
            throw it
        }
    }

    private fun recordUnsupportedEvents(events: List<ConversationLedgerEvent>, source: TimelineSyncLogSource) {
        events.filter { it.schemaVersion != SUPPORTED_SCHEMA_VERSION }
            .groupBy { it.schemaVersion }
            .forEach { (schemaVersion, unsupported) ->
                recordSync(
                    unsupported.first().sessionId, unsupported.minOf { it.sequence }, unsupported.maxOf { it.sequence },
                    unsupported.size, source, TimelineSyncLogResult.Warning, TimelineSyncLogReason.UnknownSchemaVersion, schemaVersion,
                )
            }
        events.filter { it.type is ConversationLedgerEventType.Unknown }.takeIf { it.isNotEmpty() }?.let { unsupported ->
            recordSync(
                unsupported.first().sessionId, unsupported.minOf { it.sequence }, unsupported.maxOf { it.sequence },
                unsupported.size, source, TimelineSyncLogResult.Warning, TimelineSyncLogReason.UnknownEventType,
            )
        }
    }

    private fun recordSync(
        sessionId: String,
        fromSequence: Long,
        toSequence: Long,
        eventCount: Int,
        source: TimelineSyncLogSource,
        result: TimelineSyncLogResult,
        reason: TimelineSyncLogReason,
        schemaVersion: Int? = null,
    ) = logger.record(TimelineSyncLogEvent(
        TimelineSyncLogEventName.Sync, sessionId, fromSequence, toSequence, eventCount,
        source, result, reason, schemaVersion,
    ))

    private fun recordGap(
        sessionId: String,
        fromSequence: Long,
        toSequence: Long,
        result: TimelineSyncLogResult,
        reason: TimelineSyncLogReason,
        source: TimelineSyncLogSource = TimelineSyncLogSource.Rest,
    ) = logger.record(TimelineSyncLogEvent(
        TimelineSyncLogEventName.GapResync, sessionId, fromSequence, toSequence, 0,
        source, result, reason,
    ))

    private fun requiresResync(cached: CachedTimelinePage?, cursor: Long, page: ConversationTimelinePage): Boolean {
        if (page.events.isEmpty()) return page.ledgerHeadSequence > cursor
        val known = cached?.events.orEmpty().associateBy { it.sequence }
        val newEvents = page.events.filter { it.sequence > cursor }
        if (page.events.filter { it.sequence <= cursor }.any { known[it.sequence] != it }) return true
        if (newEvents.isEmpty()) return page.ledgerHeadSequence > cursor
        return newEvents.firstOrNull()?.sequence != cursor + 1 ||
            newEvents.zipWithNext().any { (left, right) -> right.sequence != left.sequence + 1 }
    }

    private fun ConversationTimelinePage.normalizedFor(sessionId: String): ConversationTimelinePage {
        require(this.sessionId == sessionId) { "Timeline page session does not match request" }
        val normalized = events.sortedBy { it.sequence }.fold(mutableListOf<ConversationLedgerEvent>()) { result, event ->
            require(event.sessionId == sessionId) { "Timeline event session does not match request" }
            val sameSequence = result.firstOrNull { it.sequence == event.sequence }
            val sameEvent = result.firstOrNull { it.eventId == event.eventId }
            when {
                sameSequence == null && sameEvent == null -> result += event
                sameSequence == event && sameEvent == event -> Unit
                else -> throw TimelineSyncException("duplicate timeline identity has different content")
            }
            result
        }
        return copy(events = normalized)
    }

    private fun CachedTimelinePage?.cursor(): Long = this?.nextAfterSequence ?: this?.lastSequence() ?: 0L
    private fun CachedTimelinePage?.lastSequence(): Long = this?.events?.lastOrNull()?.sequence ?: 0L
    private fun CachedTimelinePage?.requiresDisplayPayloadUpgrade(): Boolean =
        this?.events?.any { event ->
            ShowOptionsTimelineProjection.requiresPayloadUpgrade(event) ||
                InteractiveToolTimelineProjection.requiresPayloadUpgrade(event)
        } == true

    private fun CachedTimelinePage.pageWith(event: ConversationLedgerEvent): ConversationTimelinePage = ConversationTimelinePage(
        sessionId = sessionId, schemaVersion = 1, ledgerHeadSequence = maxOf(ledgerHeadSequence, event.sequence),
        requestedAfterSequence = cursor(), firstSequence = event.sequence, lastSequence = event.sequence,
        nextAfterSequence = event.sequence, hasMore = false, projection = projection, events = listOf(event),
    )

    private fun CachedTimelinePage.snapshot(): ConversationTimelineSnapshot = ConversationTimelineSnapshot(
        sessionId = sessionId, ledgerHeadSequence = ledgerHeadSequence, events = events,
        projection = projection, timeline = ConversationLedgerTimelineReducer.reduceAll(events),
    )

    private fun validateRequest(accountId: String, sessionId: String, pageSize: Int) {
        require(accountId.isNotBlank()) { "accountId is required" }
        require(sessionId.isNotBlank()) { "sessionId is required" }
        require(pageSize in 1..MAX_PAGE_SIZE) { "pageSize must be between 1 and $MAX_PAGE_SIZE" }
    }

    private companion object {
        const val DEFAULT_PAGE_SIZE = 100
        const val MAX_PAGE_SIZE = 200
        const val SUPPORTED_SCHEMA_VERSION = 1
    }
}

data class ConversationTimelineSnapshot(
    val sessionId: String,
    val ledgerHeadSequence: Long,
    val events: List<ConversationLedgerEvent>,
    val projection: com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection,
    val timeline: LedgerTimelineState,
)

class TimelineSyncException(message: String) : IllegalStateException(message)

/** The only transport condition allowed to use the read-only pre-ledger compatibility view. */
class TimelineUnavailableException(message: String, cause: Throwable? = null) : IllegalStateException(message, cause)

/** Explicit server compatibility signal for a conversation that has no ledger yet. */
class TimelineLegacyNoLedgerException(message: String) : IllegalStateException(message)
