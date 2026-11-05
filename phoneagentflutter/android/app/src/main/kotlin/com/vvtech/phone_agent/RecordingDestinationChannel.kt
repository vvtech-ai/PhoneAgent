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

/** Reserve a new document before Dart obtains/downloads the recording source. */
class RecordingDestinationChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/call_recording_destination")
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: Operation? = null
    private var closed = false
    private class Operation(val id: String, var reply: MethodChannel.Result?) {
        @Volatile var cancelled = false
        var picker = true
        var working = false
        var uri: Uri? = null
    }
    init { channel.setMethodCallHandler(::handle) }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "choose" -> choose(call, result)
            "write" -> write(call, result)
            "cancel" -> {
                pending?.takeIf { it.id == call.argument<String>("id") }?.let(::cancel)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
    private fun choose(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: ""
        if (closed || pending != null || !id.matches(Regex("[a-f0-9]{32}"))) { fail(result); return }
        val name = (call.argument<String>("name") ?: "recording.m4a")
            .replace(Regex("[/\\\\\\x00-\\x1f]"), "_").take(180)
            .takeUnless { it.isBlank() || it == "." || it == ".." } ?: "recording.m4a"
        val operation = Operation(id, result)
        pending = operation
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/mp4"
                putExtra(Intent.EXTRA_TITLE, name)
            }, REQUEST)
        } catch (_: Exception) { finish(operation, null) }
    }
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val operation = pending ?: return true
        operation.picker = false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri?.scheme != "content") {
            finish(operation, false); return true
        }
        operation.uri = uri
        if (operation.cancelled || closed) { discard(operation); return true }
        operation.reply?.success(true)
        operation.reply = null
        return true
    }
    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val operation = pending
        val size = call.argument<Number>("size")?.toLong() ?: -1L
        val hash = call.argument<String>("sha256") ?: ""
        val path = call.argument<String>("path") ?: ""
        if (closed || operation == null || operation.id != call.argument<String>("id") ||
            operation.cancelled || operation.picker || operation.working || operation.uri == null ||
            size < 0 || !hash.matches(Regex("[a-f0-9]{64}"))) { fail(result); return }
        operation.reply = result
        operation.working = true
        worker.execute {
            var success = false
            try {
                val file = File(path)
                val root = File(activity.cacheDir, "phoneagent-history-recordings").canonicalFile
                check(file.absoluteFile == file.canonicalFile && file.canonicalFile.parentFile == root)
                check(file.name.matches(Regex("[a-f0-9]{64}\\.m4a")) && file.isFile && file.length() == size)
                check(!operation.cancelled)
                val digest = MessageDigest.getInstance("SHA-256")
                var copied = 0L
                file.inputStream().use { input ->
                    checkNotNull(activity.contentResolver.openOutputStream(operation.uri!!, "w")).use { output ->
                        val bytes = ByteArray(64 * 1024)
                        while (true) {
                            check(!operation.cancelled)
                            val count = input.read(bytes)
                            if (count < 0) break
                            copied += count; check(copied <= size)
                            digest.update(bytes, 0, count)
                            output.write(bytes, 0, count)
                        }
                        output.flush()
                    }
                }
                check(!operation.cancelled && copied == size &&
                    digest.digest().joinToString("") { "%02x".format(it) } == hash)
                success = true
            } catch (_: Exception) { /* Structured failure below, no private paths. */ }
            activity.runOnUiThread {
                operation.working = false
                if (success && !operation.cancelled && !closed) finish(operation, true)
                else discard(operation, failed = !operation.cancelled)
            }
        }
    }
    private fun discard(operation: Operation, failed: Boolean = false) {
        operation.working = true
        worker.execute {
            var removed = true
            operation.uri?.let { uri ->
                removed = try { DocumentsContract.deleteDocument(activity.contentResolver, uri) }
                    catch (_: Exception) { false }
            }
            activity.runOnUiThread {
                operation.working = false
                finish(operation, if (failed || !removed) null else false)
            }
        }
    }
    private fun cancel(operation: Operation) {
        if (operation.cancelled) return
        operation.cancelled = true
        operation.reply?.success(false); operation.reply = null
        if (operation.picker) activity.finishActivity(REQUEST)
        else if (!operation.working) discard(operation)
    }
    private fun finish(operation: Operation, success: Boolean?) {
        if (pending === operation) pending = null
        val reply = operation.reply; operation.reply = null
        if (reply != null) { if (success == null) fail(reply) else reply.success(success) }
        if (closed && pending == null) worker.shutdown()
    }
    private fun fail(result: MethodChannel.Result) =
        result.error("recording_destination_failed", "Recording destination unavailable", null)
    fun close() {
        closed = true
        pending?.let(::cancel)
        channel.setMethodCallHandler(null)
        if (pending == null) worker.shutdown()
    }
    companion object { private const val REQUEST = 4818 }
}
