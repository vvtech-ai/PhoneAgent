package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract.CommonDataKinds.Phone
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** System APIs only. Normalization, sorting, directory notes live in Dart. */
internal class ContactsChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/contacts")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val prefs = activity.getSharedPreferences("contacts_permission", 0)
    private var pending: MethodChannel.Result? = null
    private var closed = false
    private var permissionOnly = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "authorization" -> result.success(authorization())
                "load", "requestAuthorization" -> {
                    if (pending != null) {
                        result.error("busy", "Contacts request already active", null)
                    } else {
                        pending = result
                        permissionOnly = call.method == "requestAuthorization"
                        if (authorized()) {
                            if (permissionOnly) complete(authorization()) else read()
                        } else if (permissionOnly || call.argument<Boolean>("requestPermission") == true) {
                            prefs.edit().putBoolean("requested", true).apply()
                            activity.requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), REQUEST)
                        } else {
                            complete(authorization())
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST) return false
        if (!closed && pending != null) {
            if (permissionOnly || !authorized()) complete(authorization()) else read()
        }
        return true
    }

    private fun authorized() = activity.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun authorization(): Map<String, Any> {
        val granted = authorized()
        val requested = prefs.getBoolean("requested", false)
        return mapOf(
            "access" to if (granted) "authorized" else if (requested) "denied" else "notDetermined",
            "canRequest" to (!granted && (!requested || activity.shouldShowRequestPermissionRationale(Manifest.permission.READ_CONTACTS)))
        )
    }

    private fun read() {
        worker.execute {
            try {
                if (!authorized()) {
                    main.post { complete(mapOf("access" to "denied")) }
                    return@execute
                }
                val rows = mutableListOf<Map<String, String>>()
                val projection = arrayOf(Phone.DISPLAY_NAME, Phone.NUMBER, Phone.NORMALIZED_NUMBER, Phone.LABEL, Phone.CONTACT_ID)
                val cursor = activity.contentResolver.query(Phone.CONTENT_URI, projection, null, null, "${Phone.DISPLAY_NAME} COLLATE LOCALIZED ASC")
                    ?: throw IllegalStateException("Contacts provider unavailable")
                cursor.use {
                    while (it.moveToNext()) {
                        rows.add(mapOf(
                            "name" to (it.getString(0) ?: ""),
                            "phone" to (it.getString(1) ?: ""),
                            "normalizedPhone" to (it.getString(2) ?: ""),
                            "label" to (it.getString(3) ?: ""),
                            "contactId" to (it.getString(4) ?: "")
                        ))
                    }
                }
                main.post {
                    if (authorized()) complete(mapOf("access" to "authorized", "rows" to rows))
                    else complete(mapOf("access" to "denied"))
                }
            } catch (_: SecurityException) {
                main.post { complete(mapOf("access" to "denied")) }
            } catch (_: Exception) {
                main.post {
                    if (!closed) {
                        val result = pending
                        pending = null
                        result?.error("read_failed", "Contacts could not be read", null)
                    }
                }
            }
        }
    }

    private fun complete(value: Map<String, Any>) {
        if (closed) return
        val result = pending
        pending = null
        result?.success(value)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        pending?.error("disposed", "Contacts activity closed", null)
        pending = null
        closed = true
        worker.shutdownNow()
    }

    private companion object { const val REQUEST = 7107 }
}
