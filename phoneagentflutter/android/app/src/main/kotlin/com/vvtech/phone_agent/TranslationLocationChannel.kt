package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/** System access only; Dart owns trusted cache, UI and translation policy. */
class TranslationLocationChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/translation_location")
    private val manager = activity.getSystemService(LocationManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val permissions = arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION,
        Manifest.permission.ACCESS_FINE_LOCATION)
    private val preferences = activity.getSharedPreferences("translation_location_permission", 0)
    private var pending: MethodChannel.Result? = null
    private var requestId: String? = null
    private var permissionInFlight = false
    private var listener: LocationListener? = null
    private val cancellations = mutableListOf<CancellationSignal>()
    private var geocoding = false
    private var closed = false
    private val timeout = Runnable { finish("failed") }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "locate" -> {
                    val id = call.argument<String>("requestId")
                    when {
                        closed || activity.isFinishing || activity.isDestroyed ->
                            result.error("closed", "Location unavailable", null)
                        pending != null || permissionInFlight ->
                            result.error("location_busy", "Location request active", null)
                        id.isNullOrBlank() -> result.error("invalid", "Missing request id", null)
                        else -> {
                            pending = result
                            requestId = id
                            handler.postDelayed(timeout, 90000)
                            if (authorized()) locate(id)
                            else if (locationStatus() == "blocked") {
                                finish("blocked")
                            } else {
                                preferences.edit().putBoolean("requested", true).apply()
                                permissionInFlight = true
                                try { activity.requestPermissions(permissions, REQUEST) }
                                catch (_: Exception) { permissionInFlight = false; finish("failed") }
                            }
                        }
                    }
                }
                "cancel" -> {
                    if (call.argument<String>("requestId") == requestId) finish("failed")
                    result.success(null)
                }
                "openSettings" -> try {
                    activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${activity.packageName}")))
                    result.success(null)
                } catch (_: Exception) { result.error("settings_failed", "Settings unavailable", null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun locationStatus() = LocationPermissionPolicy.status(
        granted = authorized(),
        requested = preferences.getBoolean("requested", false) || permissions.all {
            activity.getSharedPreferences("phone_agent_permission_requests", 0).getBoolean(it, false)
        },
        canRequestAgain = permissions.any { activity.shouldShowRequestPermissionRationale(it) }
    )

    private fun authorized() = permissions.any {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun onPermissionResult(code: Int): Boolean {
        if (code != REQUEST) return false
        permissionInFlight = false
        val id = requestId ?: return true
        if (authorized()) locate(id)
        else finish(if (permissions.any { activity.shouldShowRequestPermissionRationale(it) }) "denied" else "blocked")
        return true
    }

    @Suppress("DEPRECATION", "MissingPermission")
    private fun locate(id: String) {
        if (requestId != id || closed) return
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, 30000)
        try {
            val fine = activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
                .filter { (it != LocationManager.GPS_PROVIDER || fine) && manager.isProviderEnabled(it) }
            if (providers.isEmpty() || !Geocoder.isPresent()) { finish("failed"); return }
            if (Build.VERSION.SDK_INT >= 30) {
                providers.forEach { provider ->
                    val signal = CancellationSignal()
                    cancellations.add(signal)
                    manager.getCurrentLocation(provider, signal, activity.mainExecutor) { location ->
                        if (location != null) accept(id, location)
                    }
                }
            } else {
                val callback = object : LocationListener {
                    override fun onLocationChanged(location: Location) = accept(id, location)
                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }
                listener = callback
                providers.forEach { manager.requestSingleUpdate(it, callback, Looper.getMainLooper()) }
            }
        } catch (_: Exception) { finish("failed") }
    }

    @Suppress("DEPRECATION")
    private fun accept(id: String, location: Location) {
        if (closed || requestId != id || geocoding) return
        val lat = location.latitude
        val lng = location.longitude
        if (!lat.isFinite() || !lng.isFinite() || lat !in -90.0..90.0 ||
            lng !in -180.0..180.0 || (lat == 0.0 && lng == 0.0)) return
        geocoding = true
        stopLocation()
        val geocoder = Geocoder(activity.applicationContext, Locale.CHINA)
        if (Build.VERSION.SDK_INT >= 33) {
            try {
                geocoder.getFromLocation(lat, lng, 1, object : Geocoder.GeocodeListener {
                    override fun onGeocode(addresses: MutableList<android.location.Address>) {
                        handler.post { resolved(id, addresses.firstOrNull()?.countryCode) }
                    }
                    override fun onError(errorMessage: String?) { handler.post { resolved(id, null) } }
                })
            } catch (_: Exception) { resolved(id, null) }
        } else {
            executor.execute {
                val iso = runCatching { geocoder.getFromLocation(lat, lng, 1)?.firstOrNull()?.countryCode }.getOrNull()
                handler.post { resolved(id, iso) }
            }
        }
    }

    private fun resolved(id: String, raw: String?) {
        if (closed || requestId != id) return
        val iso = raw?.trim()?.uppercase(Locale.ROOT)
        if (iso != null && iso.matches(Regex("[A-Z]{2}"))) finish("resolved", iso)
        else finish("failed")
    }

    private fun stopLocation() {
        cancellations.forEach { it.cancel() }
        cancellations.clear()
        listener?.let { runCatching { manager.removeUpdates(it) } }
        listener = null
    }

    private fun finish(status: String, iso: String? = null) {
        val result = pending
        pending = null
        requestId = null
        geocoding = false
        handler.removeCallbacks(timeout)
        stopLocation()
        result?.success(mapOf("status" to status, "countryIso" to iso))
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        finish("failed")
        executor.shutdownNow()
    }
    private companion object { const val REQUEST = 7394 }
}
