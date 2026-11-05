package com.vvtech.phone_agent

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import com.alipay.face.api.ZIMFacade
import com.alipay.face.api.ZIMFacadeBuilder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** SDK boundary only. Registration never initializes or captures device data. */
class IdentityCaptureChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/identity_capture")
    private var session: String? = null
    private var meta: String? = null
    private var pending: MethodChannel.Result? = null
    private var facade: ZIMFacade? = null
    private var preparing = false
    private var closed = false
    private var cancelled = false
    private var finishing = false
    private var releaseFailed = false
    private val releaseWaiters = mutableListOf<MethodChannel.Result>()

    init {
        channel.setMethodCallHandler { call, result ->
            val lease = call.argument<String>("session")
            if (closed || lease == null || !lease.matches(Regex("^[A-Za-z0-9_-]{1,128}$"))) {
                result.error("capture_unavailable", "Identity capture unavailable", null)
            } else when (call.method) {
                "prepare" -> prepare(lease, result)
                "capture" -> capture(lease, call.argument<String>("certifyId"), result)
                "abort" -> { if (abort(lease)) result.success(null) else releaseError(result) }
                "waitForRelease" -> {
                    if (owner !== this || session != lease) result.success(null)
                    else if (releaseFailed) releaseError(result)
                    else releaseWaiters.add(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun prepare(lease: String, result: MethodChannel.Result) {
        if (owner === this && session == lease && meta != null && pending == null) {
            result.success(meta); return
        }
        if (owner != null) { busy(result); return }
        owner = this
        session = lease
        cancelled = false
        pending = result
        preparing = true
        preparation.execute {
            val prepared = runCatching {
                ZIMFacade.install(activity.applicationContext)
                ZIMFacade.getMetaInfos(activity.applicationContext).also { require(!it.isNullOrBlank()) }
            }
            activity.runOnUiThread {
                preparing = false
                if (closed || cancelled || session != lease) {
                    reset()
                    return@runOnUiThread
                }
                val reply = pending
                pending = null
                prepared.onSuccess { value -> meta = value; reply?.success(value) }
                    .onFailure {
                        reset()
                        reply?.error("capture_unavailable", "Identity preparation failed", null)
                    }
            }
        }
    }

    private fun capture(lease: String, certifyId: String?, result: MethodChannel.Result) {
        if (owner !== this || session != lease || meta == null || pending != null) {
            busy(result); return
        }
        if (certifyId.isNullOrBlank() || certifyId.length > 4096 || activity.isFinishing || activity.isDestroyed) {
            result.error("capture_unavailable", "Identity capture unavailable", null); return
        }
        pending = result
        try {
            val instance = ZIMFacadeBuilder.create(activity)
            facade = instance
            instance.setCustomLoadingFragment(AliyunVoiceCloneLoadingFragment::class.java)
            instance.verify(certifyId, true, hashMapOf(
                "ext_params_key_use_video" to "false",
                "ext_params_key_open_fullscreen" to "false",
                "ext_params_key_screen_orientation" to "ext_params_val_screen_port"
            )) { response ->
                activity.runOnUiThread {
                    if (facade === instance && session == lease && !finishing) {
                        finishing = true
                        val reply = pending
                        pending = null
                        val payload = environment().toMutableMap().apply {
                            put("code", response?.code ?: -1)
                            // Never cross the channel with SDK device tokens/images/raw reason.
                            put("reason", SUBCODE.find(response?.reason.orEmpty().uppercase())?.value.orEmpty())
                        }
                        if (releaseFacade()) { reset(); reply?.success(payload) }
                        else reply?.let { releaseError(it) }
                    }
                }
                true
            }
        } catch (_: Throwable) {
            val reply = pending
            pending = null
            if (releaseFacade()) reset()
            // A synchronous callback may already have replied.
            reply?.error(
                "capture_unavailable", "Identity capture failed", null)
        }
    }

    private fun abort(lease: String?): Boolean {
        if (owner !== this || session != lease) return true
        val reply = pending
        cancelled = true; meta = null; pending = null
        reply?.error("capture_cancelled", "Identity capture cancelled", null)
        // An in-flight install must finish before a new SDK owner is admitted.
        if (preparing) return true
        finishing = true
        if (!releaseFacade()) return false
        reset()
        return true
    }
    private fun releaseFacade(): Boolean {
        return try {
            facade?.release()
            facade = null; releaseFailed = false
            true
        } catch (_: Throwable) {
            releaseFailed = true
            val waiters = releaseWaiters.toList(); releaseWaiters.clear()
            waiters.forEach { releaseError(it) }
            false
        }
    }
    private fun reset() {
        session = null; meta = null; pending = null; facade = null
        finishing = false; releaseFailed = false
        if (owner === this) owner = null
        val waiters = releaseWaiters.toList(); releaseWaiters.clear()
        waiters.forEach { it.success(null) }
    }
    private fun releaseError(result: MethodChannel.Result) =
        result.error("capture_release_failed", "Identity capture has not released", null)
    private fun environment(): Map<String, Any> {
        val caps = runCatching {
            val manager = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            manager.getNetworkCapabilities(manager.activeNetwork)
        }.getOrNull()
        val network = when {
            caps == null -> "NONE"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WIFI"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "CELLULAR"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ETHERNET"
            else -> "OTHER"
        }
        return mapOf("deviceModel" to Build.MODEL.orEmpty().take(64).ifBlank { "unknown" },
            "networkType" to network,
            "networkValidated" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true))
    }
    private fun busy(result: MethodChannel.Result) = result.error("capture_busy", "Identity capture is busy", null)
    fun close() { closed = true; abort(session); channel.setMethodCallHandler(null) }
    private companion object {
        var owner: IdentityCaptureChannel? = null // All ownership mutations run on main.
        val preparation = Executors.newSingleThreadExecutor()
        val SUBCODE = Regex("(?<![A-Z0-9_])[ZA]\\d{4}(?:_\\d+)?(?![A-Z0-9_])")
    }
}
