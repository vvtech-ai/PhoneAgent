package com.vvtech.phone_agent

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Read installed metadata only; no identifiers, permissions or installer. */
class AppInfoChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/app_info")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read" && call.method != "readC1" && call.method != "readEnvironment") {
                result.notImplemented()
            } else {
                try {
                    @Suppress("DEPRECATION")
                    val info = context.packageManager.getPackageInfo(context.packageName, 0)
                    @Suppress("DEPRECATION")
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                        else info.versionCode.toLong()
                    val metadata = mapOf(
                        "packageName" to context.packageName,
                        "versionName" to (info.versionName ?: ""),
                        "versionCode" to code
                    )
                    result.success(if (call.method == "read") metadata else mapOf(
                        "appVersionName" to (info.versionName ?: ""),
                        "appVersionCode" to code,
                        "sdkVersionName" to "1.0.0",
                        "osName" to "Android", "osVersion" to Build.VERSION.RELEASE,
                        "apiLevel" to Build.VERSION.SDK_INT,
                        "deviceBrand" to Build.BRAND, "deviceModel" to Build.MODEL,
                        "deviceManufacturer" to Build.MANUFACTURER,
                        "networkType" to "UNKNOWN", "platform" to "APP"
                    ) + if (call.method == "readEnvironment") mapOf(
                        "deviceHardwareModel" to Build.DEVICE
                    ) else emptyMap())
                } catch (_: Exception) {
                    result.error("APP_INFO_UNAVAILABLE", "Installed app metadata unavailable", null)
                }
            }
        }
    }

    fun close() { channel.setMethodCallHandler(null) }
}
