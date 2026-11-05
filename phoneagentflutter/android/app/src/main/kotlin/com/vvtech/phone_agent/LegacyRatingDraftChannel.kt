package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Production-package, single account/task, read-only SharedPreferences bridge. */
class LegacyRatingDraftChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/legacy_rating_draft",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else try {
                check(!closed)
                val account = call.argument<String>("accountId").orEmpty()
                val taskType = call.argument<String>("taskType").orEmpty()
                val taskId = call.argument<String>("taskId").orEmpty()
                val key = LegacyRatingDraftKey.key(account, taskType, taskId)
                val value = if (app.packageName != "com.vvtech.aiassistant") null else {
                    val raw = app.getSharedPreferences("task_rating_drafts", Context.MODE_PRIVATE)
                        .getString(key, null)
                    mapOf("version" to 1, "accountId" to account,
                        "taskType" to taskType, "taskId" to taskId,
                        "draft" to LegacyRatingDraftKey.bounded(raw))
                }
                if (!closed) result.success(value)
            } catch (_: Exception) {
                if (!closed) result.error("legacy_rating_unavailable",
                    "Local upgrade draft unavailable", null)
            }
        }
    }

    fun close() { closed = true; channel.setMethodCallHandler(null) }
}
