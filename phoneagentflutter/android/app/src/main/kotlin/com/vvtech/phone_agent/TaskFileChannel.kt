package com.vvtech.phone_agent

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** System file saving only; Dart owns download, authentication and account scope. */
class TaskFileChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/task_files")
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: Save? = null
    private var closed = false
    private val saved = mutableMapOf<String, String>()
    private class Save(val id: String, val bytes: ByteArray, val mime: String, val result: MethodChannel.Result) {
        @Volatile var cancelled = false
        var answered = false
        var picking = true
    }
    init { channel.setMethodCallHandler(::handle) }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "save" -> save(call, result)
            "cancel" -> {
                pending?.takeIf { it.id == call.argument<String>("id") }?.let { operation ->
                    operation.cancelled = true
                    if (operation.picking) {
                        activity.finishActivity(REQUEST)
                        finish(operation, null)
                    }
                }
                result.success(null)
            }
            "exists" -> {
                val location = call.argument<String>("location") ?: ""
                if (!saved.containsKey(location) || closed) { result.success(false); return }
                worker.execute {
                    val exists = try {
                        activity.contentResolver.openAssetFileDescriptor(Uri.parse(location), "r")?.use { true } ?: false
                    } catch (_: Exception) { false }
                    activity.runOnUiThread { result.success(exists) }
                }
            }
            "open" -> try {
                val location = call.argument<String>("location") ?: ""
                val mime = checkNotNull(saved[location])
                activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.parse(location), mime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                })
                result.success(null)
            } catch (_: Exception) { fail(result) }
            else -> result.notImplemented()
        }
    }
    private fun save(call: MethodCall, result: MethodChannel.Result) {
        if (closed || pending != null) { fail(result); return }
        val id = call.argument<String>("id") ?: ""
        val name = call.argument<String>("name") ?: ""
        val mime = call.argument<String>("mime") ?: ""
        val bytes = call.argument<ByteArray>("bytes")
        val docx = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        if (!id.matches(Regex("[a-f0-9]{32}")) || bytes == null || bytes.isEmpty() || bytes.size > 20 * 1024 * 1024 ||
            name.isBlank() || name.length > 180 || name.contains('/') || name.contains('\\') ||
            name.any { it.code < 32 } ||
            !(mime == "text/csv" && name.endsWith(".csv", true) || mime == docx && name.endsWith(".docx", true) ||
              mime == "application/pdf" && name.endsWith(".pdf", true) ||
              mime == "application/ofd" && name.endsWith(".ofd", true) ||
              mime == "application/xml" && name.endsWith(".xml", true))) {
            fail(result); return
        }
        val operation = Save(id, bytes, mime, result)
        pending = operation
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mime
                putExtra(Intent.EXTRA_TITLE, name)
            }, REQUEST)
        } catch (_: Exception) { finish(operation, null, failed = true) }
    }
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val operation = pending ?: return true
        operation.picking = false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri?.scheme != "content" || operation.cancelled) {
            finish(operation, null); return true
        }
        worker.execute {
            var success = false
            try {
                check(!operation.cancelled)
                checkNotNull(activity.contentResolver.openOutputStream(uri, "w")).use { output ->
                    var offset = 0
                    while (offset < operation.bytes.size) {
                        check(!operation.cancelled)
                        val count = minOf(64 * 1024, operation.bytes.size - offset)
                        output.write(operation.bytes, offset, count)
                        offset += count
                    }
                    output.flush()
                }
                check(!operation.cancelled)
                success = true
            } catch (_: Exception) {
                try { DocumentsContract.deleteDocument(activity.contentResolver, uri) } catch (_: Exception) { }
            }
            activity.runOnUiThread {
                finish(operation, if (success) uri.toString() else null, !success && !operation.cancelled)
            }
        }
        return true
    }
    private fun finish(operation: Save, location: String?, failed: Boolean = false) {
        if (pending === operation) pending = null
        if (!operation.answered) {
            operation.answered = true
            if (location != null) saved[location] = operation.mime
            if (failed) fail(operation.result) else operation.result.success(location)
        }
    }
    private fun fail(result: MethodChannel.Result) = result.error("task_file_failed", "Task file unavailable", null)
    fun close() {
        closed = true
        pending?.let { operation ->
            operation.cancelled = true
            if (operation.picking) activity.finishActivity(REQUEST)
            if (!operation.answered) { operation.answered = true; operation.result.success(null) }
        }
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
    companion object { private const val REQUEST = 6942 }
}
