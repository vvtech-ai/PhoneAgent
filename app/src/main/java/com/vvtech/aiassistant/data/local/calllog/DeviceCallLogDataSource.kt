package com.vvtech.aiassistant.data.local.calllog

import android.content.Context
import android.provider.CallLog
import com.vvtech.aiassistant.logging.AppFileLogger

internal enum class DeviceCallDirection {
    INCOMING,
    OUTGOING,
    MISSED,
    REJECTED,
    BLOCKED,
    UNKNOWN
}

internal data class DeviceCallLogEntry(
    val id: String,
    val phoneNumber: String,
    val cachedName: String,
    val startedAtMillis: Long,
    val durationSeconds: Long,
    val direction: DeviceCallDirection
)

internal class DeviceCallLogDataSource(
    context: Context
) {
    private val resolver = context.applicationContext.contentResolver

    fun recentCalls(limit: Int): List<DeviceCallLogEntry> {
        if (limit <= 0) return emptyList()
        return runCatching {
            resolver.query(
                CallLog.Calls.CONTENT_URI,
                Projection,
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(CallLog.Calls._ID)
                val numberIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val nameIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME)
                val dateIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
                val durationIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)
                val typeIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                buildList {
                    while (cursor.moveToNext() && size < limit) {
                        val number = cursor.getString(numberIndex).orEmpty().trim()
                        if (number.isBlank() || number == "-1" || number == "-2") continue
                        add(
                            DeviceCallLogEntry(
                                id = cursor.getLong(idIndex).toString(),
                                phoneNumber = number,
                                cachedName = cursor.getString(nameIndex).orEmpty().trim(),
                                startedAtMillis = cursor.getLong(dateIndex),
                                durationSeconds = cursor.getLong(durationIndex),
                                direction = deviceCallDirection(cursor.getInt(typeIndex))
                            )
                        )
                    }
                }
            }.orEmpty()
        }.getOrElse { error ->
            AppFileLogger.w(
                "DIAL_CALL_LOG",
                "event=read_failed errorType=${error.javaClass.simpleName}"
            )
            emptyList()
        }
    }

    private companion object {
        val Projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION,
            CallLog.Calls.TYPE
        )
    }
}

private fun deviceCallDirection(type: Int): DeviceCallDirection = when (type) {
    CallLog.Calls.INCOMING_TYPE -> DeviceCallDirection.INCOMING
    CallLog.Calls.OUTGOING_TYPE -> DeviceCallDirection.OUTGOING
    CallLog.Calls.MISSED_TYPE -> DeviceCallDirection.MISSED
    CallLog.Calls.REJECTED_TYPE -> DeviceCallDirection.REJECTED
    CallLog.Calls.BLOCKED_TYPE -> DeviceCallDirection.BLOCKED
    else -> DeviceCallDirection.UNKNOWN
}
