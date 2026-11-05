package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** System authorization only. Never reads contacts, location or microphone data. */
class PermissionChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/permissions")
    private var pending: MethodChannel.Result? = null
    private var pendingPermissions = emptyArray<String>()
    private val requested = activity.getSharedPreferences(
        "phone_agent_permission_requests", Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "locationStatus") {
                val permissions = arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION)
                result.success(locationStatus(permissions))
            } else if (call.method != "resolve") {
                result.notImplemented()
            } else {
                val permissions = when (call.argument<String>("permission")) {
                    "contacts" -> arrayOf(Manifest.permission.READ_CONTACTS)
                    "microphone" -> arrayOf(Manifest.permission.RECORD_AUDIO)
                    "callLog" -> arrayOf(Manifest.permission.READ_CALL_LOG)
                    "location" -> arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.ACCESS_FINE_LOCATION)
                    else -> emptyArray()
                }
                when {
                    permissions.isEmpty() -> result.success("unavailable")
                    status(permissions) == "granted" -> result.success("granted")
                    status(permissions) == "blocked" -> result.success("blocked")
                    call.argument<Boolean>("request") != true -> result.success("denied")
                    pending != null -> result.error("permission_busy", "Permission request active", null)
                    activity.isFinishing || activity.isDestroyed -> result.error("closed", "Activity closed", null)
                    else -> {
                        pending = result
                        pendingPermissions = permissions
                        try {
                            activity.requestPermissions(permissions, REQUEST)
                            requested.edit().apply {
                                permissions.forEach { putBoolean(it, true) }
                            }.apply()
                        } catch (_: Exception) {
                            finishError("permission_failed")
                        }
                    }
                }
            }
        }
    }

    private fun authorized(permissions: Array<String>) = permissions.any {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    private fun locationStatus(permissions: Array<String>) = LocationPermissionPolicy.status(
        granted = authorized(permissions),
        requested = activity.getSharedPreferences("translation_location_permission", 0)
            .getBoolean("requested", false) || permissions.all { requested.getBoolean(it, false) },
        canRequestAgain = permissions.any { activity.shouldShowRequestPermissionRationale(it) }
    )

    private fun status(permissions: Array<String>): String = if (
        permissions.contains(Manifest.permission.ACCESS_COARSE_LOCATION)
    ) locationStatus(permissions) else when {
        authorized(permissions) -> "granted"
        permissions.all { requested.getBoolean(it, false) &&
            !activity.shouldShowRequestPermissionRationale(it) } -> "blocked"
        else -> "denied"
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending
        val status = status(pendingPermissions)
        pending = null
        pendingPermissions = emptyArray()
        result?.success(status)
        return true
    }

    private fun finishError(code: String) {
        val result = pending
        pending = null
        pendingPermissions = emptyArray()
        result?.error(code, "Permission request unavailable", null)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        finishError("closed")
    }

    private companion object { const val REQUEST = 7382 }
}
