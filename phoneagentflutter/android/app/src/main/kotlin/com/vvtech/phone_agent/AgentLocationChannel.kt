package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Already-authorized foreground sample only. No permission prompt or storage. */
class AgentLocationChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/agent_location")
    private val manager = activity.getSystemService(LocationManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val legacyGeocoderBusy = AtomicBoolean(false)
    private var pending: MethodChannel.Result? = null
    private var requestId: String? = null
    private var sample: Location? = null
    private var listener: LocationListener? = null
    private val signals = mutableListOf<CancellationSignal>()
    private val fallback = Runnable { fallback() }
    private val deadline = Runnable { finish() }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> {
                    val id = call.argument<String>("requestId")
                    when {
                        pending != null -> result.error("busy", "Sample pending", null)
                        id.isNullOrBlank() -> result.error("invalid", "Missing request id", null)
                        !allowed() || activity.isFinishing || activity.isDestroyed -> result.success(null)
                        else -> {
                            requestId = id
                            pending = result
                            handler.postDelayed(deadline, 9000)
                            handler.postDelayed(fallback, 8000)
                            locate(id)
                        }
                    }
                }
                "cancel" -> {
                    if (call.argument<String>("requestId") == requestId) finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun granted(permission: String) = activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    private fun allowed() = granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)

    @Suppress("MissingPermission", "DEPRECATION")
    private fun locate(id: String) {
        try {
            val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
                .filter { (it != LocationManager.GPS_PROVIDER || granted(Manifest.permission.ACCESS_FINE_LOCATION)) && manager.isProviderEnabled(it) }
            if (providers.isEmpty()) { finish(); return }
            if (Build.VERSION.SDK_INT >= 30) {
                var remaining = providers.size
                providers.forEach { provider ->
                    val signal = CancellationSignal()
                    signals.add(signal)
                    manager.getCurrentLocation(provider, signal, activity.mainExecutor) { value ->
                        if (requestId == id && sample == null) {
                            val accuracy = if (granted(Manifest.permission.ACCESS_FINE_LOCATION)) 1500f else 3000f
                            if (valid(value, 120000L, accuracy)) accept(id, value!!)
                            else if (--remaining == 0) fallback()
                        }
                    }
                }
            } else {
                val callback = object : LocationListener {
                    override fun onLocationChanged(value: Location) {
                        val accuracy = if (granted(Manifest.permission.ACCESS_FINE_LOCATION)) 1500f else 3000f
                        if (requestId == id && sample == null && valid(value, 120000L, accuracy)) accept(id, value)
                    }
                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }
                listener = callback
                providers.forEach { manager.requestSingleUpdate(it, callback, Looper.getMainLooper()) }
            }
        } catch (_: Exception) { fallback() }
    }

    @Suppress("MissingPermission")
    private fun fallback() {
        val id = requestId ?: return
        if (sample != null) return
        val candidates = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER, LocationManager.GPS_PROVIDER)
            .mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .filter { valid(it, 300000L, if (it.provider == LocationManager.GPS_PROVIDER) 500f else 1000f) }
        val best = candidates.minByOrNull {
            (if (it.time > 0) (System.currentTimeMillis() - it.time).coerceAtLeast(0) else Long.MAX_VALUE / 40) * 10 +
                (if (it.hasAccuracy()) it.accuracy.toLong() else 5000L)
        }
        if (best == null) finish() else accept(id, best)
    }

    private fun valid(value: Location?, age: Long, accuracy: Float): Boolean {
        if (value == null || !allowed()) return false
        val lat = value.latitude
        val lng = value.longitude
        return lat.isFinite() && lng.isFinite() && lat in -90.0..90.0 && lng in -180.0..180.0 &&
            !(lat == 0.0 && lng == 0.0) && (value.time <= 0 || System.currentTimeMillis() - value.time <= age) &&
            (!value.hasAccuracy() || value.accuracy <= accuracy)
    }

    @Suppress("DEPRECATION")
    private fun accept(id: String, value: Location) {
        if (requestId != id || sample != null) return
        sample = value
        stopLocation()
        handler.removeCallbacks(fallback)
        if (!Geocoder.isPresent()) { finish(); return }
        val geocoder = Geocoder(activity.applicationContext, Locale.CHINA)
        if (Build.VERSION.SDK_INT >= 33) {
            try {
                geocoder.getFromLocation(value.latitude, value.longitude, 1, object : Geocoder.GeocodeListener {
                    override fun onGeocode(addresses: MutableList<android.location.Address>) {
                        handler.post { if (requestId == id) finish(addresses.firstOrNull()?.getAddressLine(0)) }
                    }
                    override fun onError(errorMessage: String?) { handler.post { if (requestId == id) finish() } }
                })
            } catch (_: Exception) { finish() }
        } else {
            // A platform geocoder may block beyond our deadline; never queue
            // an unbounded number of obsolete tasks behind that single call.
            if (!legacyGeocoderBusy.compareAndSet(false, true)) { finish(); return }
            executor.execute {
                val address = runCatching { geocoder.getFromLocation(value.latitude, value.longitude, 1)?.firstOrNull()?.getAddressLine(0) }.getOrNull()
                legacyGeocoderBusy.set(false)
                handler.post { if (requestId == id) finish(address) }
            }
        }
    }

    private fun stopLocation() {
        signals.forEach { it.cancel() }
        signals.clear()
        listener?.let { runCatching { manager.removeUpdates(it) } }
        listener = null
    }

    private fun finish(address: String? = null) {
        val callback = pending
        val value = sample
        pending = null
        requestId = null
        sample = null
        handler.removeCallbacks(fallback)
        handler.removeCallbacks(deadline)
        stopLocation()
        callback?.success(value?.let { mapOf("lat" to it.latitude, "lng" to it.longitude, "address" to (address ?: "")) })
    }

    fun close() {
        channel.setMethodCallHandler(null)
        finish()
        executor.shutdownNow()
    }
}
