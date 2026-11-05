package com.vvtech.phone_agent

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Transports URLs only; the shared policy validates environment and invitation. */
class InviteChannel(private val activity: Activity, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "phone_agent/invite")
    private val events = EventChannel(messenger, "phone_agent/invite_links")
    private var sink: EventChannel.EventSink? = null
    private var initial: String? = null
    private var pending: MethodChannel.Result? = null
    private var bytes: ByteArray? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    init {
        receive(activity.intent)
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialLink" -> { val value = initial; initial = null; result.success(value) }
                "savePoster" -> save(call.arguments as? ByteArray, result)
                else -> result.notImplemented()
            }
        }
    }
    fun receive(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val value = intent.dataString ?: return
        val valid = InviteEntryReceipt.parse(activity, value) != null
        val fresh = valid && InviteEntryReceipt.accept(activity, intent)
        intent.data = null
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(InviteEntryReceipt.EXTRA)
        if (!fresh) return
        if (sink == null) initial = value else sink?.success(value)
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }
    private fun save(data: ByteArray?, result: MethodChannel.Result) {
        if (pending != null) { result.error("BUSY", "保存进行中", null); return }
        if (data == null || data.size !in 8..10485760 ||
            !data.take(8).toByteArray().contentEquals(byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10))) {
            result.error("INVALID_IMAGE", "图片无效", null); return
        }
        pending = result
        if (Build.VERSION.SDK_INT < 29) {
            bytes = data
            try {
                activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "image/png"
                    putExtra(Intent.EXTRA_TITLE, "PhoneAgent-invite-${System.currentTimeMillis()}.png")
                }, 4819)
            } catch (_: Exception) { finish(false, true) }
            return
        }
        worker.execute {
            var uri: android.net.Uri? = null
            try {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, "PhoneAgent-invite-${System.currentTimeMillis()}.png")
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/PhoneAgent")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val resolver = activity.contentResolver
                uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: error("Unable to create image")
                resolver.openOutputStream(uri)?.use { it.write(data) } ?: error("Unable to write image")
                values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
                if (resolver.update(uri, values, null, null) != 1) error("Unable to publish image")
                main.post { finish(true, false) }
            } catch (_: Exception) {
                uri?.let { runCatching { activity.contentResolver.delete(it, null, null) } }
                main.post { finish(false, true) }
            }
        }
    }
    fun onActivityResult(request: Int, result: Int, intent: Intent?): Boolean {
        if (request != 4819) return false
        val data = bytes
        val uri = intent?.data
        if (result != Activity.RESULT_OK || uri == null || data == null) { finish(false, false); return true }
        worker.execute {
            try {
                activity.contentResolver.openOutputStream(uri)?.use { it.write(data) } ?: error("Unable to write")
                main.post { finish(true, false) }
            } catch (_: Exception) { main.post { finish(false, true) } }
        }
        return true
    }
    private fun finish(saved: Boolean, error: Boolean) {
        val result = pending; pending = null; bytes = null
        if (error) result?.error("SAVE_FAILED", "图片保存失败", null) else result?.success(saved)
    }
    fun close() {
        methods.setMethodCallHandler(null); events.setStreamHandler(null); sink = null
        finish(false, true); worker.shutdown()
    }
}
