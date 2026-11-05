package com.vvtech.phone_agent.ota

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/** Android-only system operations; account, UI and update policy stay in Dart. */
class UpdateInstallChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/update_install")
    private val store = UpdateDownloadStore(activity.applicationContext)
    private val executor = Executors.newSingleThreadExecutor()
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in setOf("begin", "restore", "peek", "query", "cancel", "canInstall", "permission", "install")) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            executor.execute {
                try {
                    val values = call.arguments as? Map<*, *> ?: error("Missing arguments")
                    val scope = values["scope"] as? String ?: error("Missing scope")
                    require(UpdateDownloadStore.SCOPE.matches(scope))
                    var intent: Intent? = null
                    val value = synchronized(UpdateDownloadStore.LOCK) {
                        fun job() = store.requireJob(scope, values["job"] as? String ?: error("Missing job"))
                        when (call.method) {
                            "peek" -> store.peek(scope)
                            "begin" -> store.begin(scope, UpdateRelease.parse(values, activity.packageName), values)
                            "restore" -> store.restore(scope, UpdateRelease.parse(values, activity.packageName))
                            "query" -> store.snapshot(job())
                            "cancel" -> { store.cancel(job()); null }
                            "canInstall" -> activity.packageManager.canRequestPackageInstalls()
                            "permission" -> {
                                intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
                                null
                            }
                            "install" -> {
                                check(activity.packageManager.canRequestPackageInstalls())
                                val owned = job()
                                val file = UpdatePackageStager.stage(store.completedFile(owned), store.privateFile(owned))
                                // Evidence failure must not veto the system installer.
                                runCatching {
                                    store.recordInstallEvidence(owned, UpdatePackageStager.fingerprint(file))
                                }
                                val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.flutter.ota.fileprovider", file)
                                @Suppress("DEPRECATION")
                                val launch = Intent(Intent.ACTION_INSTALL_PACKAGE)
                                    .setDataAndType(uri, "application/vnd.android.package-archive")
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                intent = launch
                                null
                            }
                            else -> error("Unsupported method")
                        }
                    }
                    activity.runOnUiThread {
                        if (!closed) {
                            try {
                                intent?.let { activity.startActivity(it) }
                                // Return means dispatched, never installed or permission granted.
                                result.success(value)
                            } catch (_: Exception) { result.error("OTA_HANDOFF_FAILED", "System update handoff unavailable", null) }
                        }
                    }
                } catch (error: Exception) {
                    activity.runOnUiThread {
                        if (!closed) {
                            val code = if (error is FileNotFoundException) "OTA_FILE_UNAVAILABLE" else "OTA_OPERATION_FAILED"
                            result.error(code, "Update operation unavailable", null)
                        }
                    }
                }
            }
        }
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        // Finish queued persistence work; DownloadManager survives engine disposal.
        executor.shutdown()
    }
}
