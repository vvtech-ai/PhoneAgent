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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.features.assistant_ui.AssistantConfirmationDialog
import com.vvtech.aiassistant.features.translation_call.state.TranslationRegionStateHolder
import kotlinx.coroutines.launch

internal data class DialerLocationConsentState(
    val promptShown: Boolean,
    val systemPermissionRequested: Boolean
)

internal data class DialerLocationConsentCallbacks(
    val onPromptShownChange: (Boolean) -> Unit,
    val onSystemPermissionRequestedChange: (Boolean) -> Unit,
    val onTranslationEnabledChange: (Boolean) -> Unit
)

internal enum class DialerLocationDialogKind {
    REQUEST,
    BLOCKED
}

internal enum class DialerLocationEntryAction {
    REFRESH_REGION,
    SHOW_REQUEST,
    NONE
}

internal data class DialerLocationPermissionGateState(
    val dialogKind: DialerLocationDialogKind?,
    val decisionComplete: Boolean,
    val onTranslationToggleRequested: (Boolean) -> Unit,
    val onCancel: () -> Unit,
    val onConfirm: () -> Unit
)

@Composable
internal fun rememberDialerLocationPermissionGate(
    translateEnabled: Boolean,
    consent: DialerLocationConsentState,
    callbacks: DialerLocationConsentCallbacks
): DialerLocationPermissionGateState {
    val context = LocalContext.current
    val appContext = context.applicationContext
    val activity = context.findActivity()
    val scope = rememberCoroutineScope()
    val regionHolder = remember(appContext) { TranslationRegionStateHolder.from(appContext) }
    var dialogKind by remember { mutableStateOf<DialerLocationDialogKind?>(null) }
    var enableAfterGrant by remember { mutableStateOf(false) }
    var decisionComplete by remember {
        mutableStateOf(appContext.hasLocationPermission() || consent.promptShown)
    }

    fun onPermissionGranted() {
        scope.launch { regionHolder.refresh() }
        if (enableAfterGrant) callbacks.onTranslationEnabledChange(true)
        enableAfterGrant = false
        dialogKind = null
        decisionComplete = true
    }

    val settingsLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        if (appContext.hasLocationPermission()) {
            onPermissionGranted()
        } else {
            callbacks.onTranslationEnabledChange(false)
            enableAfterGrant = false
            dialogKind = null
            decisionComplete = true
        }
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        if (result.values.any { it }) {
            onPermissionGranted()
        } else {
            callbacks.onTranslationEnabledChange(false)
            enableAfterGrant = false
            dialogKind = null
            decisionComplete = true
        }
    }

    fun showPermissionPath(enableTranslation: Boolean) {
        if (!enableTranslation) {
            callbacks.onTranslationEnabledChange(false)
            return
        }
        if (appContext.hasLocationPermission()) {
            scope.launch { regionHolder.refresh() }
            callbacks.onTranslationEnabledChange(true)
            return
        }
        enableAfterGrant = true
        decisionComplete = false
        callbacks.onPromptShownChange(true)
        dialogKind = dialerLocationDialogKind(
            systemPermissionRequested = consent.systemPermissionRequested,
            canRequestAgain = activity?.canRequestLocationPermissionAgain() ?: true
        )
    }

    LaunchedEffect(consent.promptShown) {
        when (
            dialerLocationEntryAction(
                hasPermission = appContext.hasLocationPermission(),
                promptShown = consent.promptShown
            )
        ) {
            DialerLocationEntryAction.REFRESH_REGION -> regionHolder.refresh()
            DialerLocationEntryAction.SHOW_REQUEST -> {
                decisionComplete = false
                enableAfterGrant = translateEnabled
                callbacks.onPromptShownChange(true)
                dialogKind = DialerLocationDialogKind.REQUEST
            }
            DialerLocationEntryAction.NONE -> Unit
        }
    }

    return DialerLocationPermissionGateState(
        dialogKind = dialogKind,
        decisionComplete = decisionComplete,
        onTranslationToggleRequested = ::showPermissionPath,
        onCancel = {
            callbacks.onTranslationEnabledChange(false)
            enableAfterGrant = false
            dialogKind = null
            decisionComplete = true
        },
        onConfirm = {
            when (dialogKind) {
                DialerLocationDialogKind.REQUEST -> {
                    callbacks.onSystemPermissionRequestedChange(true)
                    dialogKind = null
                    permissionLauncher.launch(LocationPermissions)
                }
                DialerLocationDialogKind.BLOCKED -> {
                    dialogKind = null
                    settingsLauncher.launch(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${appContext.packageName}")
                        )
                    )
                }
                null -> Unit
            }
        }
    )
}

internal fun shouldShowInitialDialerLocationPrompt(
    hasPermission: Boolean,
    promptShown: Boolean
): Boolean = !hasPermission && !promptShown

internal fun dialerLocationEntryAction(
    hasPermission: Boolean,
    promptShown: Boolean
): DialerLocationEntryAction = when {
    hasPermission -> DialerLocationEntryAction.REFRESH_REGION
    !promptShown -> DialerLocationEntryAction.SHOW_REQUEST
    else -> DialerLocationEntryAction.NONE
}

internal fun dialerLocationDialogKind(
    systemPermissionRequested: Boolean,
    canRequestAgain: Boolean
): DialerLocationDialogKind =
    if (systemPermissionRequested && !canRequestAgain) {
        DialerLocationDialogKind.BLOCKED
    } else {
        DialerLocationDialogKind.REQUEST
    }

@Composable
internal fun DialerLocationPermissionDialogHost(
    state: DialerLocationPermissionGateState
) {
    val kind = state.dialogKind ?: return
    val blocked = kind == DialerLocationDialogKind.BLOCKED
    AssistantConfirmationDialog(
        title = if (blocked) "需要位置权限" else "开启位置权限",
        message = if (blocked) {
            "位置权限已被关闭。请前往系统设置开启；未开启时仅可使用普通电话。"
        } else {
            "开启位置权限，以确认所在地区适用的实时翻译模型和通话线路，并提供更稳定的通话服务。不开启时仅可使用普通通话。"
        },
        dismissLabel = "暂不开启",
        confirmLabel = if (blocked) "前往系统设置" else "开启位置权限",
        onDismiss = state.onCancel,
        onConfirm = state.onConfirm,
        dismissButtonModifier = Modifier.testTag("interaction:dial-location-later"),
        confirmButtonModifier = Modifier.testTag("interaction:dial-location-confirm")
    )
}

private fun Context.hasLocationPermission(): Boolean =
    LocationPermissions.any { permission ->
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }

private fun Activity.canRequestLocationPermissionAgain(): Boolean =
    LocationPermissions.any { permission ->
        ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
    }

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private val LocationPermissions = arrayOf(
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACCESS_COARSE_LOCATION
)
