package com.vvtech.phone_agent

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Fixed same-package source only. Never log credentials or accept file paths. */
class LegacySessionChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/legacy_session")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read" && call.method != "consume") {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val value = if (app.packageName != "com.vvtech.aiassistant") {
                            // Dev/profile/test packages cannot access or import prod data.
                            if (call.method == "consume") true else null
                        } else {
                            val marker = app.getSharedPreferences(
                                "phoneagent_flutter_migration", Context.MODE_PRIVATE
                            )
                            if (call.method == "consume") {
                                if (!marker.getBoolean("v65_auth_consumed", false) &&
                                    !marker.edit().putBoolean("v65_auth_consumed", true).commit()) {
                                    throw IllegalStateException("Migration marker unavailable")
                                }
                                true
                            } else if (marker.getBoolean("v65_auth_consumed", false)) {
                                null
                            } else {
                                val old = app.getSharedPreferences("account_identity", Context.MODE_PRIVATE)
                                val phone = old.getString("phone", null)
                                val token = old.getString("voice_clone_access_token", null)
                                if (phone.isNullOrBlank() || token.isNullOrBlank()) null
                                else mapOf("version" to 1, "phone" to phone, "accessToken" to token)
                            }
                        }
                        main.post { if (!closed) result.success(value) }
                    } catch (_: Exception) {
                        main.post {
                            if (!closed) result.error(
                                "LEGACY_SESSION_UNAVAILABLE", "Local upgrade data unavailable", null
                            )
                        }
                    }
                }
            }
        }
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
