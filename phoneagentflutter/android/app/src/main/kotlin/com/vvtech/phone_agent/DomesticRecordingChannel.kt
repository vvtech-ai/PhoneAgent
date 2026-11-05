package com.vvtech.phone_agent

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class DomesticRecordingChannel(context: Context, messenger: BinaryMessenger) {
    private val root = File(context.noBackupFilesDir, "domestic-recordings").apply { mkdirs() }.canonicalFile
    private val channel = MethodChannel(messenger, "phone_agent/domestic_recording")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val closed = AtomicBoolean(false)
    private val busy = AtomicBoolean(false)
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "directory") { result.success(root.path); return@setMethodCallHandler }
            if (call.method != "encode") { result.notImplemented(); return@setMethodCallHandler }
            val input = call.argument<String>("pcmPath")?.let { File(it).canonicalFile }
            val output = call.argument<String>("m4aPath")?.let { File(it).canonicalFile }
            val relative = input?.path?.removePrefix(root.path + File.separator)
            val pattern = Regex("^translation-recordings/[a-f0-9]{64}/[a-f0-9]{64}/mix\\.pcm16$")
            if (closed.get() || input == null || output == null || relative == null || !pattern.matches(relative) ||
                output.parentFile != input.parentFile || output.name != "recording.m4a" || output.exists() ||
                input.length() !in 2..(300L * 1024 * 1024) || input.length() % 2 != 0L || !busy.compareAndSet(false, true)) {
                result.error("recording_encode_unavailable", "录音编码不可用", null)
                return@setMethodCallHandler
            }
            worker.execute {
                val ok = runCatching { DomesticAacEncoder.encode(input, output) { closed.get() } }.isSuccess
                busy.set(false)
                main.post {
                    if (ok && !closed.get()) result.success(null)
                    else result.error("recording_encode_failed", "录音编码失败", null)
                }
            }
        }
    }
    fun close() {
        closed.set(true)
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
