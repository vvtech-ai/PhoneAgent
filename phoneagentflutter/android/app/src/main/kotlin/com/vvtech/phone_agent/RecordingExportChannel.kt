package com.vvtech.phone_agent

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Only a private-cache boundary and system export; no account/network logic. */
class RecordingExportChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/history_recordings")
    private val worker = Executors.newSingleThreadExecutor()
    private val root get() = File(activity.cacheDir, "phoneagent-history-recordings")
    private var pending: Export? = null
    private var closed = false
    private class Export(val id: String, val result: MethodChannel.Result) {
        @Volatile var cancelled = false
        var answered = false
        var picker = false
        var staging: File? = null
    }
    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "root" -> try {
                check(root.mkdirs() || root.isDirectory)
                result.success(root.canonicalPath)
            } catch (_: Exception) { fail(result) }
            "cancel" -> {
                pending?.takeIf { it.id == call.argument<String>("id") }?.let(::cancel)
                result.success(null)
            }
            "save" -> save(call, result)
            else -> result.notImplemented()
        }
    }

    private fun save(call: MethodCall, result: MethodChannel.Result) {
        if (closed || pending != null) { fail(result); return }
        val id = call.argument<String>("id") ?: ""
        val path = call.argument<String>("path") ?: ""
        val size = call.argument<Number>("size")?.toLong() ?: -1L
        val hash = call.argument<String>("sha256") ?: ""
        val name = (call.argument<String>("name") ?: "recording.m4a")
            .replace(Regex("[/\\\\\\x00-\\x1f]"), "_").take(180)
            .takeUnless { it.isBlank() || it == "." || it == ".." } ?: "recording.m4a"
        val mime = call.argument<String>("contentType")?.takeIf { it.startsWith("audio/") } ?: "audio/mp4"
        if (!id.matches(Regex("[a-f0-9]{32}")) || size < 0 || !hash.matches(Regex("[a-f0-9]{64}"))) {
            fail(result); return
        }
        val operation = Export(id, result)
        pending = operation
        worker.execute {
            var staged: File? = null
            try {
                val file = File(path)
                check(file.absoluteFile == file.canonicalFile && file.canonicalFile.parentFile == root.canonicalFile)
                check(file.name.matches(Regex("[a-f0-9]{64}\\.m4a")) && file.isFile && file.length() == size)
                staged = File.createTempFile("history-export-", ".m4a", activity.cacheDir)
                val digest = MessageDigest.getInstance("SHA-256")
                var copied = 0L
                file.inputStream().use { input -> staged.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        check(!operation.cancelled)
                        val count = input.read(buffer)
                        if (count < 0) break
                        copied += count
                        check(copied <= size)
                        digest.update(buffer, 0, count)
                        output.write(buffer, 0, count)
                    }
                    output.fd.sync()
                } }
                check(copied == size && digest.digest().joinToString("") { "%02x".format(it) } == hash)
                val prepared = staged
                activity.runOnUiThread {
                    operation.staging = prepared
                    if (closed || operation.cancelled || pending !== operation) { finish(operation, false); return@runOnUiThread }
                    try {
                        operation.picker = true
                        activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mime
                            putExtra(Intent.EXTRA_TITLE, name)
                        }, REQUEST)
                    } catch (_: Exception) { finish(operation, null) }
                }
            } catch (_: Exception) {
                staged?.delete()
                activity.runOnUiThread { finish(operation, if (operation.cancelled) false else null) }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val operation = pending ?: return true
        operation.picker = false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri?.scheme != "content") {
            finish(operation, false); return true
        }
        worker.execute {
            var success = false
            try {
                check(!operation.cancelled)
                val source = checkNotNull(operation.staging)
                source.inputStream().use { input ->
                    checkNotNull(activity.contentResolver.openOutputStream(uri, "w")).use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            check(!operation.cancelled)
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                        output.flush()
                    }
                }
                check(!operation.cancelled)
                success = true
            } catch (_: Exception) {
                // ACTION_CREATE_DOCUMENT returns this operation's newly created document.
                removeIncomplete(uri)
            }
            activity.runOnUiThread { finish(operation, if (success) true else if (operation.cancelled) false else null) }
        }
        return true
    }

    private fun removeIncomplete(uri: Uri) {
        try { DocumentsContract.deleteDocument(activity.contentResolver, uri) } catch (_: Exception) { }
    }
    private fun finish(operation: Export, success: Boolean?) {
        operation.staging?.delete()
        if (pending === operation) pending = null
        if (!operation.answered) {
            operation.answered = true
            if (success == null) fail(operation.result) else operation.result.success(success)
        }
    }
    private fun cancel(operation: Export) {
        operation.cancelled = true
        if (!operation.answered) { operation.answered = true; operation.result.success(false) }
        if (operation.picker) activity.finishActivity(REQUEST)
        // Worker/result callback owns cleanup; never delete a file while it is being copied.
    }
    private fun fail(result: MethodChannel.Result) =
        result.error("recording_export_failed", "Recording export unavailable", null)
    fun close() {
        closed = true
        pending?.let(::cancel)
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
    companion object { private const val REQUEST = 4817 }
}
