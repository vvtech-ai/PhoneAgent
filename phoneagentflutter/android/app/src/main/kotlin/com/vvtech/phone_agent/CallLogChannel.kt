package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Read-only system boundary. Permission sequencing and UI belong to Dart. */
internal class CallLogChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/call_log")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            when {
                call.method != "load" -> result.notImplemented()
                closed -> result.success(mapOf("access" to "failed"))
                pending != null -> result.error("busy", "Call log read already active", null)
                !authorized() -> result.success(mapOf("access" to "denied"))
                else -> {
                    pending = result
                    read()
                }
            }
        }
    }

    private fun authorized() = activity.checkSelfPermission(Manifest.permission.READ_CALL_LOG) ==
        PackageManager.PERMISSION_GRANTED

    private fun read() {
        worker.execute {
            val snapshot = try {
                if (!authorized()) {
                    mapOf("access" to "denied")
                } else {
                    val rows = mutableListOf<Map<String, Any>>()
                    val projection = arrayOf(CallLog.Calls._ID, CallLog.Calls.NUMBER,
                        CallLog.Calls.CACHED_NAME, CallLog.Calls.DATE)
                    val cursor = activity.contentResolver.query(CallLog.Calls.CONTENT_URI,
                        projection, null, null, "${CallLog.Calls.DATE} DESC")
                        ?: throw IllegalStateException("Call log provider unavailable")
                    cursor.use {
                        while (!Thread.currentThread().isInterrupted &&
                            rows.size < 20 && it.moveToNext()) {
                            val phone = it.getString(1).orEmpty().trim()
                            if (phone.isEmpty() || phone == "-1" || phone == "-2") continue
                            rows.add(mapOf(
                                "id" to it.getLong(0).toString(),
                                "phone" to phone,
                                "name" to it.getString(2).orEmpty().trim(),
                                "startedAtMillis" to it.getLong(3)
                            ))
                        }
                    }
                    mapOf("access" to "ready", "rows" to rows)
                }
            } catch (_: SecurityException) {
                mapOf("access" to "denied")
            } catch (_: Exception) {
                mapOf("access" to "failed")
            }
            main.post {
                if (!closed) {
                    val result = pending
                    pending = null
                    result?.success(if (authorized()) snapshot else mapOf("access" to "denied"))
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        closed = true
        pending?.success(mapOf("access" to "failed"))
        pending = null
        worker.shutdownNow()
    }
}
