package com.vvtech.aiassistant.data.local.timeline

import android.content.Context
import com.vvtech.aiassistant.domain.conversation.ConversationTimelinePage

/** Transactional, removable cache. It stores durable events and server projection only. */
class TimelineCacheStore internal constructor(
    private val dao: TimelineCacheDao,
) {
    constructor(context: Context) : this(SQLiteTimelineCacheDao(TimelineCacheDatabase(context.applicationContext)))

    fun writePage(accountId: String, page: ConversationTimelinePage) {
        require(accountId.isNotBlank()) { "accountId is required" }
        dao.replacePage(accountId, page)
    }

    fun read(accountId: String, sessionId: String): CachedTimelinePage? {
        require(accountId.isNotBlank()) { "accountId is required" }
        return dao.read(accountId, sessionId)
    }

    fun clear(accountId: String, sessionId: String) {
        require(accountId.isNotBlank()) { "accountId is required" }
        require(sessionId.isNotBlank()) { "sessionId is required" }
        dao.clear(accountId, sessionId)
    }
}
