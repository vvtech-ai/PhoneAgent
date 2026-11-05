package com.vvtech.phone_agent

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Thin OS handoff. ACTION_DIAL never places a call without system confirmation. */
internal class SystemDialerChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/system_dialer")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
            } else {
                val number = call.argument<String>("number").orEmpty()
                if (!Regex("\\+?[0-9*#]+").matches(number)) {
                    result.success("invalid")
                } else {
                    try {
                        activity.startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null)))
                        result.success("opened")
                    } catch (_: ActivityNotFoundException) {
                        result.success("unsupported")
                    } catch (_: Exception) {
                        result.success("failed")
                    }
                }
            }
        }
    }
    fun close() = channel.setMethodCallHandler(null)
}
