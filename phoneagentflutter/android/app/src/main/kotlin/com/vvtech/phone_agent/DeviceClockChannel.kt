package com.vvtech.phone_agent

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/** Read-only wall clock and zone evidence; formatting stays in shared Dart. */
class DeviceClockChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/device_clock")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") result.notImplemented()
            else {
                val now = System.currentTimeMillis()
                val zone = TimeZone.getDefault()
                result.success(mapOf("epochMillis" to now,
                    "offsetSeconds" to zone.getOffset(now) / 1000, "timezone" to zone.id))
            }
        }
    }
    fun close() = channel.setMethodCallHandler(null)
}
