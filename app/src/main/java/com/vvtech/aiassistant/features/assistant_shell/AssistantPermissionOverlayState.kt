package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind

internal class AssistantPermissionOverlayState(
    networkModeNameState: MutableState<String>,
    showNetworkBlockerState: MutableState<Boolean>,
    requestedPermissionNameState: MutableState<String?>,
    pendingPermissionActionState: MutableState<String>,
    microphonePermissionGrantedState: MutableState<Boolean>,
    storagePermissionGrantedState: MutableState<Boolean>,
    contactsPermissionGrantedState: MutableState<Boolean>,
    phonePermissionGrantedState: MutableState<Boolean>
) {
    var networkModeName by networkModeNameState
    var showNetworkBlocker by showNetworkBlockerState
    var requestedPermissionName by requestedPermissionNameState
    var pendingPermissionAction by pendingPermissionActionState
    var microphonePermissionGranted by microphonePermissionGrantedState
    var storagePermissionGranted by storagePermissionGrantedState
    var contactsPermissionGranted by contactsPermissionGrantedState
    var phonePermissionGranted by phonePermissionGrantedState

    val networkMode: V88NetworkMode
        get() = runCatching { V88NetworkMode.valueOf(networkModeName) }.getOrDefault(V88NetworkMode.Normal)

    val requestedPermission: V88PermissionKind?
        get() = requestedPermissionName?.let { runCatching { V88PermissionKind.valueOf(it) }.getOrNull() }

    fun showNetworkBlocker() {
        showNetworkBlocker = true
    }

    fun dismissNetworkBlocker() {
        showNetworkBlocker = false
    }

    fun setPendingPermissionAction(action: String, permissionName: String? = null) {
        requestedPermissionName = permissionName
        pendingPermissionAction = action
    }

    fun clearRequestedPermission() {
        requestedPermissionName = null
        pendingPermissionAction = ""
    }

    fun takePendingPermissionAction(): String {
        val action = pendingPermissionAction
        pendingPermissionAction = ""
        return action
    }

    fun resetForSession() {
        clearRequestedPermission()
        dismissNetworkBlocker()
    }
}

@Composable
internal fun rememberAssistantPermissionOverlayState(context: Context): AssistantPermissionOverlayState =
    AssistantPermissionOverlayState(
        networkModeNameState = rememberSaveable { mutableStateOf(V88NetworkMode.Normal.name) },
        showNetworkBlockerState = rememberSaveable { mutableStateOf(false) },
        requestedPermissionNameState = rememberSaveable { mutableStateOf<String?>(null) },
        pendingPermissionActionState = rememberSaveable { mutableStateOf("") },
        microphonePermissionGrantedState = rememberSaveable {
            mutableStateOf(context.isPermissionGranted(Manifest.permission.RECORD_AUDIO))
        },
        storagePermissionGrantedState = rememberSaveable { mutableStateOf(false) },
        contactsPermissionGrantedState = rememberSaveable {
            mutableStateOf(context.isPermissionGranted(Manifest.permission.READ_CONTACTS))
        },
        phonePermissionGrantedState = rememberSaveable {
            mutableStateOf(context.isPermissionGranted(Manifest.permission.CALL_PHONE))
        }
    )

private fun Context.isPermissionGranted(permission: String): Boolean {
    return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
}
