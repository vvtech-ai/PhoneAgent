package com.vvtech.aiassistant.features.assistant_calls

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.features.translation_call.state.TranslationRegionStateHolder
import kotlinx.coroutines.launch

internal enum class DialCountryLocationStatus {
    IDLE,
    REQUESTING_PERMISSION,
    LOCATING,
    SUCCESS,
    DENIED,
    BLOCKED,
    UNSUPPORTED,
    FAILED
}

internal enum class DialCountryLocationPermissionAction {
    LOCATE,
    REQUEST_PERMISSION,
    OPEN_SETTINGS
}

internal data class DialCountryLocationState(
    val status: DialCountryLocationStatus,
    val country: DialCountry? = null,
    val message: String,
    val actionLabel: String = "获取",
    val requestLocation: () -> Unit = {}
)

@Composable
internal fun rememberDialCountryLocationState(): DialCountryLocationState {
    val context = LocalContext.current
    val appContext = context.applicationContext
    val activity = context.findDialCountryActivity()
    val scope = rememberCoroutineScope()
    val holder = remember(appContext) { TranslationRegionStateHolder.from(appContext) }
    val regionState by holder.state.collectAsState()
    var transientStatus by remember { mutableStateOf<DialCountryLocationStatus?>(null) }
    var permissionRequested by rememberSaveable { mutableStateOf(false) }

    fun locate() {
        transientStatus = DialCountryLocationStatus.LOCATING
        scope.launch {
            holder.refresh()
            transientStatus = null
        }
    }

    val settingsLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        if (appContext.hasAnyLocationPermission()) {
            locate()
        } else {
            transientStatus = DialCountryLocationStatus.BLOCKED
        }
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        if (result.values.any { it }) {
            locate()
        } else {
            transientStatus = if (
                activity?.canRequestDialCountryLocationPermissionAgain() == false
            ) {
                DialCountryLocationStatus.BLOCKED
            } else {
                DialCountryLocationStatus.DENIED
            }
        }
    }
    val request = {
        when (
            dialCountryLocationPermissionAction(
                hasPermission = appContext.hasAnyLocationPermission(),
                permissionRequested = permissionRequested,
                canRequestAgain =
                activity?.canRequestDialCountryLocationPermissionAgain() ?: true
            )
        ) {
            DialCountryLocationPermissionAction.LOCATE -> locate()
            DialCountryLocationPermissionAction.REQUEST_PERMISSION -> {
                permissionRequested = true
                transientStatus = DialCountryLocationStatus.REQUESTING_PERMISSION
                permissionLauncher.launch(DialCountryLocationPermissions)
            }
            DialCountryLocationPermissionAction.OPEN_SETTINGS -> {
                transientStatus = DialCountryLocationStatus.BLOCKED
                settingsLauncher.launch(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${appContext.packageName}")
                    )
                )
            }
        }
    }
    return dialCountryLocationState(
        regionState = regionState,
        transientStatus = transientStatus,
        hasPermission = appContext.hasAnyLocationPermission()
    )
        .copy(requestLocation = request)
}

internal fun dialCountryLocationPermissionAction(
    hasPermission: Boolean,
    permissionRequested: Boolean,
    canRequestAgain: Boolean
): DialCountryLocationPermissionAction = when {
    hasPermission -> DialCountryLocationPermissionAction.LOCATE
    permissionRequested && !canRequestAgain ->
        DialCountryLocationPermissionAction.OPEN_SETTINGS
    else -> DialCountryLocationPermissionAction.REQUEST_PERMISSION
}

private fun Context.hasAnyLocationPermission(): Boolean {
    return DialCountryLocationPermissions.any { permission ->
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}

private fun Activity.canRequestDialCountryLocationPermissionAgain(): Boolean =
    DialCountryLocationPermissions.any { permission ->
        ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
    }

private tailrec fun Context.findDialCountryActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findDialCountryActivity()
    else -> null
}

internal fun dialCountryLocationState(
    regionState: TranslationRegionState,
    transientStatus: DialCountryLocationStatus? = null,
    hasPermission: Boolean = false
): DialCountryLocationState {
    if (transientStatus != null) {
        return DialCountryLocationState(
            status = transientStatus,
            message = when (transientStatus) {
                DialCountryLocationStatus.REQUESTING_PERMISSION -> "正在请求定位权限…"
                DialCountryLocationStatus.LOCATING -> "正在获取当前位置…"
                DialCountryLocationStatus.DENIED -> "未获得定位权限，点击重试"
                DialCountryLocationStatus.BLOCKED -> "位置权限已关闭，请前往设置"
                else -> "点击获取当前位置"
            },
            actionLabel = if (transientStatus == DialCountryLocationStatus.BLOCKED) {
                "前往设置"
            } else {
                "获取"
            }
        )
    }
    return when (regionState) {
        TranslationRegionState.Resolving -> DialCountryLocationState(
            status = DialCountryLocationStatus.LOCATING,
            message = "正在获取当前位置…"
        )
        is TranslationRegionState.Resolved -> {
            val country = resolveLocatedDialCountry(regionState.countryIso)
            if (country == null) {
                DialCountryLocationState(
                    status = DialCountryLocationStatus.UNSUPPORTED,
                    message = "当前所在国家或地区暂不支持拨号区号选择"
                )
            } else {
                DialCountryLocationState(
                    status = DialCountryLocationStatus.SUCCESS,
                    country = country,
                    message = "当前位置 · ${country.name} ${country.dialCode}"
                )
            }
        }
        is TranslationRegionState.Unavailable -> {
            val idle = regionState.reason == "尚未获取可信位置"
            DialCountryLocationState(
                status = if (idle) {
                    DialCountryLocationStatus.IDLE
                } else {
                    DialCountryLocationStatus.FAILED
                },
                message = when {
                    idle -> "点击获取当前位置"
                    hasPermission -> "无法确定当前位置，请检查系统定位后重试"
                    else -> "${regionState.reason}，点击重试"
                }
            )
        }
    }
}

private val DialCountryLocationPermissions = arrayOf(
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACCESS_COARSE_LOCATION
)
