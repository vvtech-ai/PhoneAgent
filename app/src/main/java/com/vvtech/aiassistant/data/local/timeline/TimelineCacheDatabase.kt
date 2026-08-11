package com.vvtech.aiassistant.data.local.timeline

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

internal class TimelineCacheDatabase(
    context: Context,
    name: String = DATABASE_NAME,
) : SQLiteOpenHelper(context, name, null, VERSION) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE timeline_event_cache (
                account_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                sequence INTEGER NOT NULL,
                event_id TEXT NOT NULL,
                event_json TEXT NOT NULL,
                PRIMARY KEY(account_id, session_id, sequence),
                UNIQUE(account_id, session_id, event_id)
            )
        """.trimIndent())
        db.execSQL("""
            CREATE TABLE timeline_cache_state (
                account_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                ledger_head_sequence INTEGER NOT NULL,
                next_after_sequence INTEGER,
                projection_json TEXT NOT NULL,
                PRIMARY KEY(account_id, session_id)
            )
        """.trimIndent())
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.delete("timeline_event_cache", null, null)
            db.delete("timeline_cache_state", null, null)
        }
    }

    private companion object {
        const val DATABASE_NAME = "conversation_timeline_cache.db"
        const val VERSION = 2
    }
}
