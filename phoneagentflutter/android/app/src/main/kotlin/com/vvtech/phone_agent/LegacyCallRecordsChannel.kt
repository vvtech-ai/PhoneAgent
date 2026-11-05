package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Same-package fixed-key read only. No access to system CallLog or old writes. */
class LegacyCallRecordsChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/legacy_call_records",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else try {
                check(!closed)
                val account = call.argument<String>("accountId").orEmpty()
                require(account.length in 1..256 && account != "guest" &&
                    account.matches(Regex("[A-Za-z0-9_.-]+")))
                val value = if (app.packageName != "com.vvtech.aiassistant") null else {
                    val raw = app.getSharedPreferences("index9_native_screen", Context.MODE_PRIVATE)
                        .getString("final_call_records_$account", null)
                    // Bound before UTF-8 allocation; no truncation or partial imports.
                    require(raw == null || (raw.length <= MAX_BYTES && raw.toByteArray(Charsets.UTF_8).size <= MAX_BYTES))
                    mapOf("version" to 1, "accountId" to account, "records" to raw)
                }
                if (!closed) result.success(value)
            } catch (_: Exception) {
                if (!closed) result.error("legacy_records_unavailable", "Local upgrade records unavailable", null)
            }
        }
    }

    fun close() { closed = true; channel.setMethodCallHandler(null) }
    private companion object { const val MAX_BYTES = 16 * 1024 * 1024 }
}
