package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.data.local.calllog.DeviceCallDirection
import com.vvtech.aiassistant.data.local.calllog.DeviceCallLogEntry
import org.junit.Assert.assertEquals
import org.junit.Test

class DeviceCallLogMapperTest {
    @Test
    fun systemEntryKeepsRawNumberForSystemDialer() {
        val result = deviceCallLogToRecentCall(
            DeviceCallLogEntry(
                id = "42",
                phoneNumber = "010-8888-6666",
                cachedName = "前台",
                startedAtMillis = 123L,
                durationSeconds = 8L,
                direction = DeviceCallDirection.OUTGOING
            )
        )

        assertEquals("010-8888-6666", result.phoneNumber)
        assertEquals("前台", result.displayName)
        assertEquals(DialRecentCallSource.SYSTEM, result.source)
        assertEquals(DialRecentCallKind.NORMAL, result.kind)
        assertEquals(DialRecentCallDirection.OUTGOING, result.direction)
        assertEquals(DialRecentCallStatus.COMPLETED, result.status)
    }

    @Test
    fun missedSystemEntryMapsToMissedStatus() {
        val result = deviceCallLogToRecentCall(
            DeviceCallLogEntry(
                id = "43",
                phoneNumber = "13800138000",
                cachedName = "",
                startedAtMillis = 456L,
                durationSeconds = 0L,
                direction = DeviceCallDirection.MISSED
            )
        )

        assertEquals(DialRecentCallDirection.MISSED, result.direction)
        assertEquals(DialRecentCallStatus.MISSED, result.status)
    }
}
