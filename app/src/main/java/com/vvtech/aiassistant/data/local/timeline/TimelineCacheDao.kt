package com.vvtech.aiassistant.data.local.timeline

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import com.google.gson.Gson
import com.google.gson.JsonParser
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineEventDto
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineWireMapper
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection

internal interface TimelineCacheDao {
    fun replacePage(accountId: String, page: ConversationTimelinePage)
    fun read(accountId: String, sessionId: String): CachedTimelinePage?
    fun clear(accountId: String, sessionId: String)
}

internal class SQLiteTimelineCacheDao(
    private val database: TimelineCacheDatabase,
    private val failpoint: TimelineCacheFailpoint = TimelineCacheFailpoint.None,
) : TimelineCacheDao {
    override fun replacePage(accountId: String, page: ConversationTimelinePage) {
        validate(page)
        val db = database.writableDatabase
        db.beginTransaction()
        try {
            page.events.forEach { event -> insertEvent(db, accountId, event) }
            failpoint.afterEventsInserted()
            db.insertWithOnConflict("timeline_cache_state", null, ContentValues().apply {
                put("account_id", accountId)
                put("session_id", page.sessionId)
                put("ledger_head_sequence", page.ledgerHeadSequence)
                put("next_after_sequence", page.nextAfterSequence)
                put("projection_json", gson.toJson(page.projection))
            }, SQLiteDatabase.CONFLICT_REPLACE)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    override fun read(accountId: String, sessionId: String): CachedTimelinePage? {
        val state = database.readableDatabase.query(
            "timeline_cache_state", arrayOf("ledger_head_sequence", "next_after_sequence", "projection_json"),
            "account_id = ? AND session_id = ?", arrayOf(accountId, sessionId), null, null, null,
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            CachedTimelineState(
                ledgerHeadSequence = cursor.getLong(0),
                nextAfterSequence = cursor.takeIf { !it.isNull(1) }?.getLong(1),
                projection = gson.fromJson(cursor.getString(2), ConversationTimelineProjection::class.java),
            )
        }
        val events = database.readableDatabase.query(
            "timeline_event_cache", arrayOf("event_json"), "account_id = ? AND session_id = ?",
            arrayOf(accountId, sessionId), null, null, "sequence ASC",
        ).use { cursor -> buildList { while (cursor.moveToNext()) add(decode(cursor.getString(0))) } }
        return CachedTimelinePage(sessionId, state.ledgerHeadSequence, state.nextAfterSequence, state.projection, events)
    }

    override fun clear(accountId: String, sessionId: String) {
        val db = database.writableDatabase
        db.beginTransaction()
        try {
            val where = "account_id = ? AND session_id = ?"
            val arguments = arrayOf(accountId, sessionId)
            db.delete("timeline_event_cache", where, arguments)
            db.delete("timeline_cache_state", where, arguments)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    private fun insertEvent(db: SQLiteDatabase, accountId: String, event: ConversationLedgerEvent) {
        val rawJson = encode(event)
        val values = ContentValues().apply {
            put("account_id", accountId)
            put("session_id", event.sessionId)
            put("sequence", event.sequence)
            put("event_id", event.eventId)
            put("event_json", rawJson)
        }
        if (db.insertWithOnConflict("timeline_event_cache", null, values, SQLiteDatabase.CONFLICT_IGNORE) == -1L &&
            !sameStoredEvent(db, accountId, event, rawJson)
        ) throw TimelineCacheConflict("duplicate identity has different durable content")
    }

    private fun sameStoredEvent(db: SQLiteDatabase, accountId: String, event: ConversationLedgerEvent, raw: String): Boolean =
        db.query(
            "timeline_event_cache", arrayOf("event_json"),
            "account_id = ? AND session_id = ? AND (sequence = ? OR event_id = ?)",
            arrayOf(accountId, event.sessionId, event.sequence.toString(), event.eventId), null, null, null,
        ).use { cursor -> cursor.moveToFirst() && cursor.getString(0) == raw }

    private fun validate(page: ConversationTimelinePage) {
        require(page.events.all { it.sessionId == page.sessionId }) { "Page event session does not match page" }
        require(page.events.zipWithNext().all { (before, after) -> before.sequence < after.sequence }) { "Page must be ordered" }
    }

    private fun encode(event: ConversationLedgerEvent): String = gson.toJson(ConversationTimelineWireMapper.toDto(event))
    private fun decode(raw: String): ConversationLedgerEvent = ConversationTimelineWireMapper.toDomain(
        gson.fromJson(JsonParser().parse(raw), ConversationTimelineEventDto::class.java)
    )

    private companion object { val gson = Gson() }
}

internal data class CachedTimelineState(
    val ledgerHeadSequence: Long,
    val nextAfterSequence: Long?,
    val projection: ConversationTimelineProjection,
)

data class CachedTimelinePage(
    val sessionId: String,
    val ledgerHeadSequence: Long,
    val nextAfterSequence: Long?,
    val projection: ConversationTimelineProjection,
    val events: List<ConversationLedgerEvent>,
)

fun interface TimelineCacheFailpoint {
    fun afterEventsInserted()
    object None : TimelineCacheFailpoint { override fun afterEventsInserted() = Unit }
}

class TimelineCacheConflict(message: String) : IllegalStateException(message)
