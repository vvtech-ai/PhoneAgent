package com.vvtech.aiassistant.data.repository.timeline

import com.vvtech.aiassistant.logging.AppFileLogger
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

enum class TimelineSyncLogEventName(val wireName: String) {
    Sync("TIMELINE_SYNC"),
    GapResync("TIMELINE_GAP_RESYNC"),
}

enum class TimelineSyncLogSource(val wireName: String) {
    Rest("rest"),
    Sse("sse"),
}

enum class TimelineSyncLogResult(val wireName: String) {
    Started("started"),
    Success("success"),
    Detected("detected"),
    Warning("warning"),
    Failure("failure"),
}

enum class TimelineSyncLogReason(val wireName: String) {
    SyncRequested("sync_requested"),
    PageSynced("page_synced"),
    SseMerged("sse_merged"),
    DuplicateIgnored("duplicate_ignored"),
    SequenceGap("sequence_gap"),
    LocalAhead("local_ahead"),
    DuplicateConflict("duplicate_conflict"),
    DisplayPayloadUpgrade("display_payload_upgrade"),
    FullResyncStarted("full_resync_started"),
    FullResyncCompleted("full_resync_completed"),
    CacheReadFailed("cache_read_failed"),
    CacheWriteFailed("cache_write_failed"),
    CacheClearFailed("cache_clear_failed"),
    UnknownSchemaVersion("unknown_schema_version"),
    UnknownEventType("unknown_event_type"),
}

data class TimelineSyncLogEvent(
    val eventName: TimelineSyncLogEventName,
    val sessionId: String,
    val fromSequence: Long,
    val toSequence: Long,
    val eventCount: Int,
    val source: TimelineSyncLogSource,
    val result: TimelineSyncLogResult,
    val reason: TimelineSyncLogReason,
    val schemaVersion: Int? = null,
)

fun interface TimelineSyncLogger {
    fun record(event: TimelineSyncLogEvent)
}

/** Production timeline logger. Only the closed contract below can reach the file/logcat sink. */
class AppFileTimelineSyncLogger(
    private val write: (tag: String, message: String) -> Unit = { tag, message ->
        AppFileLogger.i(tag, message)
    },
) : TimelineSyncLogger {
    override fun record(event: TimelineSyncLogEvent) {
        write(TAG, TimelineSyncLogContract.format(event))
    }

    private companion object {
        const val TAG = "TIMELINE_STATE"
    }
}

internal object TimelineSyncLogContract {
    val allowedFields: Set<String> = setOf(
        "logEvent",
        "sessionId",
        "fromSequence",
        "toSequence",
        "eventCount",
        "syncSource",
        "result",
        "reason",
        "schemaVersion",
    )

    fun fields(event: TimelineSyncLogEvent): Map<String, String> = linkedMapOf<String, String>().apply {
        put("logEvent", event.eventName.wireName)
        put("sessionId", event.sessionId.stableLogHash())
        put("fromSequence", event.fromSequence.toString())
        put("toSequence", event.toSequence.toString())
        put("eventCount", event.eventCount.toString())
        put("syncSource", event.source.wireName)
        put("result", event.result.wireName)
        put("reason", event.reason.wireName)
        event.schemaVersion?.let { put("schemaVersion", it.toString()) }
    }.also { require(allowedFields.containsAll(it.keys)) }

    fun format(event: TimelineSyncLogEvent): String = fields(event)
        .entries
        .joinToString(separator = " ") { (key, value) -> "$key=$value" }

    private fun String.stableLogHash(): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(toByteArray(StandardCharsets.UTF_8))
        return "sha256:" + digest.take(HASH_BYTES).joinToString(separator = "") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }

    private const val HASH_BYTES = 12
}
