package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Thin upgrade-only file bridge; business filtering and recovery stay in Dart. */
class LegacyTranslationArchiveChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/legacy_translation_archive",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else try {
                check(!closed)
                val account = call.argument<String>("accountId").orEmpty()
                val value = if (app.packageName != "com.vvtech.aiassistant") null else {
                    mapOf("version" to 1, "accountId" to account,
                        "pending" to LegacyTranslationArchiveFile.read(app.filesDir, account))
                }
                if (!closed) result.success(value)
            } catch (_: Exception) {
                if (!closed) result.error("legacy_translation_unavailable",
                    "Local upgrade archive unavailable", null)
            }
        }
    }

    fun close() { closed = true; channel.setMethodCallHandler(null) }
}
