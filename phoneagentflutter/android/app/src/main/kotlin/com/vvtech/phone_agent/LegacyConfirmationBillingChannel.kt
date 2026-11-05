package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Only digest-addressed, bounded v65 billing snapshots; old preferences stay read-only. */
class LegacyConfirmationBillingChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/legacy_confirmation_billing",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") result.notImplemented() else try {
                check(!closed)
                val keys = LegacyCallAdmissionKeys.validate(call.argument<List<*>>("keys").orEmpty())
                val value = if (app.packageName != "com.vvtech.aiassistant") null else {
                    val prefs = app.getSharedPreferences("index9_native_screen", Context.MODE_PRIVATE)
                    mapOf("version" to 1, "snapshots" to keys.associateWith {
                        prefs.getString("task_call_confirmation_billing_$it", null)?.also { raw ->
                            require(raw.length <= 4096)
                        }
                    })
                }
                if (!closed) result.success(value)
            } catch (_: Exception) {
                if (!closed) result.error("legacy_billing_unavailable", "Local upgrade snapshot unavailable", null)
            }
        }
    }
    fun close() { closed = true; channel.setMethodCallHandler(null) }
}
