package com.vvtech.aiassistant.features.assistant_calls

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat

internal data class DialerCallLogPermissionState(
    val permissionGranted: Boolean
)

@Composable
internal fun rememberDialerCallLogPermissionState(
    locationDecisionComplete: Boolean,
    permissionRequested: Boolean,
    onPermissionRequestedChange: (Boolean) -> Unit
): DialerCallLogPermissionState {
    val context = LocalContext.current
    var permissionGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_CALL_LOG
            ) == PackageManager.PERMISSION_GRANTED
        )
    }
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        permissionGranted = granted
    }
    LaunchedEffect(locationDecisionComplete, permissionGranted, permissionRequested) {
        when (
            nextDialerPermissionAction(
                locationDecisionComplete = locationDecisionComplete,
                callLogPermissionGranted = permissionGranted,
                callLogPermissionRequested = permissionRequested
            )
        ) {
            DialerPermissionSequenceAction.REQUEST_CALL_LOG -> {
                onPermissionRequestedChange(true)
                launcher.launch(Manifest.permission.READ_CALL_LOG)
            }
            DialerPermissionSequenceAction.LOAD_CALL_LOG,
            DialerPermissionSequenceAction.WAIT_FOR_LOCATION,
            DialerPermissionSequenceAction.NONE -> Unit
        }
    }
    return DialerCallLogPermissionState(permissionGranted)
}
