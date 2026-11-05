package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class LegacyCallAdmissionChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/legacy_call_admission",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else try {
                check(!closed)
                val digests = LegacyCallAdmissionKeys.validate(call.argument<List<*>>("keys").orEmpty())
                val value = if (app.packageName != "com.vvtech.aiassistant") null else {
                    val prefs = app.getSharedPreferences("index9_native_screen", Context.MODE_PRIVATE)
                    mapOf("version" to 1, "markers" to digests.associateWith {
                        prefs.getBoolean(LegacyCallAdmissionKeys.preferenceKey(it), false)
                    })
                }
                if (!closed) result.success(value)
            } catch (_: Exception) {
                if (!closed) result.error("legacy_notice_unavailable",
                    "Local upgrade marker unavailable", null)
            }
        }
    }

    fun close() { closed = true; channel.setMethodCallHandler(null) }
}
