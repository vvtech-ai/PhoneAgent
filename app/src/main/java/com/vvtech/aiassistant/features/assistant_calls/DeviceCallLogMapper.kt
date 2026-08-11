package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.data.local.calllog.DeviceCallDirection
import com.vvtech.aiassistant.data.local.calllog.DeviceCallLogEntry

internal fun deviceCallLogToRecentCall(entry: DeviceCallLogEntry): DialRecentCall =
    DialRecentCall(
        id = entry.id,
        phoneNumber = entry.phoneNumber,
        displayName = entry.cachedName,
        startedAtMillis = entry.startedAtMillis,
        durationSeconds = entry.durationSeconds,
        direction = when (entry.direction) {
            DeviceCallDirection.INCOMING -> DialRecentCallDirection.INCOMING
            DeviceCallDirection.OUTGOING -> DialRecentCallDirection.OUTGOING
            DeviceCallDirection.MISSED -> DialRecentCallDirection.MISSED
            DeviceCallDirection.REJECTED,
            DeviceCallDirection.BLOCKED,
            DeviceCallDirection.UNKNOWN -> DialRecentCallDirection.UNKNOWN
        },
        status = when (entry.direction) {
            DeviceCallDirection.MISSED -> DialRecentCallStatus.MISSED
            DeviceCallDirection.REJECTED,
            DeviceCallDirection.BLOCKED -> DialRecentCallStatus.FAILED
            else -> DialRecentCallStatus.COMPLETED
        },
        source = DialRecentCallSource.SYSTEM,
        kind = DialRecentCallKind.NORMAL
    )
