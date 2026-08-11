package com.vvtech.aiassistant.location

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import androidx.core.os.CancellationSignal
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

data class DeviceLocationResult(
    val userContext: UserContextPayload? = null,
    val summary: String = "",
    val success: Boolean = false
)

class FusedLocationProvider(private val appContext: Context) {

    private val currentAccuracyThreshold: Float
        get() = if (hasFineLocationPermission) 1_500f else 3_000f

    private val hasFineLocationPermission: Boolean
        get() = ContextCompat.checkSelfPermission(
            appContext,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    suspend fun locateOnce(): DeviceLocationResult {
        if (!hasLocationPermission()) {
            return DeviceLocationResult(summary = "未授权定位，将使用通用推荐。")
        }

        val locationManager = appContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return DeviceLocationResult(summary = "设备定位服务不可用，将使用通用推荐。")

        if (!LocationManagerCompat.isLocationEnabled(locationManager)) {
            return DeviceLocationResult(summary = "系统定位服务未开启，将使用通用推荐。")
        }

        requestSystemCurrentLocation(locationManager)?.let { location ->
            val source = if (location.provider == LocationManager.GPS_PROVIDER) {
                "GPS"
            } else {
                "基站/WiFi"
            }
            return toSuccessResult(location, "已通过${source}获取当前位置")
        }

        requestSystemLastKnownLocation(locationManager)?.let { location ->
            return toSuccessResult(location, "已使用系统最近一次有效定位")
        }

        return DeviceLocationResult(summary = "当前位置精度不足，将使用通用推荐。请打开系统定位并稍后重试。")
    }

    private fun hasLocationPermission(): Boolean {
        val fineGranted = ContextCompat.checkSelfPermission(
            appContext,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            appContext,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fineGranted || coarseGranted
    }

    private fun toSuccessResult(location: Location, summary: String): DeviceLocationResult {
        val accuracySuffix = if (location.hasAccuracy() && location.accuracy > 0f) {
            "（精度约 ${location.accuracy.toInt()} 米）"
        } else {
            ""
        }
        return DeviceLocationResult(
            userContext = UserContextPayload(
                lat = location.latitude,
                lng = location.longitude
            ),
            summary = summary + accuracySuffix + "，城市和区域将由服务端补全。",
            success = true
        )
    }

    private suspend fun requestSystemCurrentLocation(locationManager: LocationManager): Location? {
        val providers = buildList {
            if (isProviderEnabled(locationManager, LocationManager.NETWORK_PROVIDER)) {
                add(LocationManager.NETWORK_PROVIDER)
            }
            if (hasFineLocationPermission &&
                isProviderEnabled(locationManager, LocationManager.GPS_PROVIDER)
            ) {
                add(LocationManager.GPS_PROVIDER)
            }
        }
        if (providers.isEmpty()) return null

        return withTimeoutOrNull(8_000L) {
            coroutineScope {
                val results = Channel<Location?>(capacity = providers.size)
                val jobs = providers.map { provider ->
                    launch {
                        results.send(
                            runCatching {
                                awaitLocationManagerCurrentLocation(locationManager, provider)
                            }.getOrNull()
                        )
                    }
                }
                repeat(providers.size) {
                    val current = validateLocation(
                        results.receive(),
                        maxAgeMillis = 2 * 60_000L,
                        maxAccuracyMeters = currentAccuracyThreshold
                    )
                    if (current != null) {
                        jobs.forEach { it.cancel() }
                        results.close()
                        return@coroutineScope current
                    }
                }
                results.close()
                null
            }
        }
    }

    private fun isProviderEnabled(locationManager: LocationManager, provider: String): Boolean =
        runCatching { locationManager.isProviderEnabled(provider) }.getOrDefault(false)

    private fun requestSystemLastKnownLocation(locationManager: LocationManager): Location? {
        val candidates = listOfNotNull(
            runCatching { locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull(),
            runCatching { locationManager.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER) }.getOrNull(),
            runCatching { locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull()
        ).mapNotNull { raw ->
            val accuracy = when {
                raw.provider == LocationManager.GPS_PROVIDER -> 500f
                else -> 1_000f
            }
            validateLocation(raw, maxAgeMillis = 5 * 60_000L, maxAccuracyMeters = accuracy)
        }
        return candidates.minByOrNull { candidateScore(it) }
    }

    @SuppressLint("MissingPermission")
    private suspend fun awaitLocationManagerCurrentLocation(
        locationManager: LocationManager,
        provider: String
    ): Location? = suspendCancellableCoroutine { continuation ->
        val cancellationSignal = CancellationSignal()
        continuation.invokeOnCancellation { cancellationSignal.cancel() }

        runCatching {
            LocationManagerCompat.getCurrentLocation(
                locationManager,
                provider,
                cancellationSignal,
                ContextCompat.getMainExecutor(appContext)
            ) { location ->
                if (continuation.isActive) {
                    continuation.resume(location)
                }
            }
        }.onFailure {
            if (continuation.isActive) {
                continuation.resume(null)
            }
        }
    }

    private fun validateLocation(
        location: Location?,
        maxAgeMillis: Long,
        maxAccuracyMeters: Float
    ): Location? {
        if (location == null) return null
        if (!location.latitude.isFinite() || !location.longitude.isFinite()) return null
        if (location.latitude !in -90.0..90.0 || location.longitude !in -180.0..180.0) return null
        if (location.latitude == 0.0 && location.longitude == 0.0) return null
        val ageMillis = locationAgeMillis(location)
        if (ageMillis != null && ageMillis > maxAgeMillis) return null
        if (location.hasAccuracy() && location.accuracy > maxAccuracyMeters) return null
        return location
    }

    private fun locationAgeMillis(location: Location): Long? {
        val time = location.time
        if (time <= 0L) return null
        return (System.currentTimeMillis() - time).coerceAtLeast(0L)
    }

    private fun candidateScore(location: Location): Long {
        val ageScore = locationAgeMillis(location) ?: Long.MAX_VALUE / 4
        val accuracyScore = if (location.hasAccuracy()) location.accuracy.toLong() else 5_000L
        return ageScore * 10 + accuracyScore
    }
}
