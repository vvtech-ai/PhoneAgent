package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.*

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.features.assistant.AssistantContactRuntimeController
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.CoroutineScope

internal data class AssistantRootContactPermissionRuntimeDeps(
    val context: Context,
    val scope: CoroutineScope,
    val assistantUiState: Index9AssistantUiState,
    val contactsPermissionGranted: Boolean,
    val contactRuntime: AssistantContactRuntimeController,
    val permissionOverlayState: AssistantPermissionOverlayState,
    val navigationState: AssistantNavigationState,
    val assistantViewModel: AssistantViewModel
)

internal class AssistantRootContactPermissionRuntime(
    val launchers: AssistantContactPermissionLaunchers
)

@Composable
internal fun rememberAssistantRootContactPermissionRuntime(
    deps: AssistantRootContactPermissionRuntimeDeps
): AssistantRootContactPermissionRuntime {
    val agentContactLookupState = rememberAssistantAgentContactLookupState()
    var showSettingsDialog by rememberSaveable { mutableStateOf(false) }
    val openContacts = {
        showSettingsDialog = false
        deps.permissionOverlayState.clearRequestedPermission()
        deps.navigationState.applyMainTab(FinalMainTab.Contacts)
        deps.contactRuntime.refreshDeviceContacts()
    }
    val settingsLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        val granted = deps.context.hasContactsPermission()
        deps.permissionOverlayState.contactsPermissionGranted = granted
        AppFileLogger.i(
            CONTACT_PERMISSION_LOG_TAG,
            "event=settings_return result=${if (granted) "granted" else "denied"}"
        )
        if (granted) {
            openContacts()
        } else {
            Toast.makeText(
                deps.context,
                "请在系统设置中开启通讯录权限",
                Toast.LENGTH_SHORT
            ).show()
        }
    }
    val contactPermissionLaunchers = rememberAssistantContactPermissionLaunchers(
        AssistantContactPermissionLauncherCallbacks(
            onContactsPermissionResult = { granted ->
                deps.permissionOverlayState.contactsPermissionGranted = granted
                val shouldShowRationale = !granted &&
                    deps.context.shouldShowContactsPermissionRationale()
                val action = resolveContactPermissionResult(granted, shouldShowRationale)
                AppFileLogger.i(
                    CONTACT_PERMISSION_LOG_TAG,
                    "event=system_result result=${if (granted) "granted" else "denied"} " +
                        "shouldShowRationale=$shouldShowRationale action=${action.name}"
                )
                when (action) {
                    ContactPermissionResultAction.OPEN_CONTACTS -> openContacts()
                    ContactPermissionResultAction.SHOW_RETRY_MESSAGE -> {
                        deps.permissionOverlayState.clearRequestedPermission()
                        Toast.makeText(
                            deps.context,
                            "需要通讯录权限才能使用此功能",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                    ContactPermissionResultAction.OPEN_APP_SETTINGS -> {
                        deps.permissionOverlayState.clearRequestedPermission()
                        showSettingsDialog = true
                    }
                }
            },
            onAgentContactsPermissionResult = { granted ->
                deps.permissionOverlayState.contactsPermissionGranted = granted
                if (granted) {
                    deps.contactRuntime.refreshDeviceContacts {
                        agentContactLookupState.markPermissionRetry()
                    }
                } else {
                    deps.contactRuntime.clearContactRecords()
                    agentContactLookupState.markPermissionRetry()
                }
            }
        )
    )

    if (showSettingsDialog) {
        AssistantContactPermissionSettingsDialog(
            onDismiss = { showSettingsDialog = false },
            onOpenSettings = {
                showSettingsDialog = false
                settingsLauncher.launch(deps.context.applicationDetailsSettingsIntent())
            }
        )
    }

    AssistantAgentContactLookupEffects(
        context = deps.context,
        assistantUiState = deps.assistantUiState,
        contactsPermissionGranted = deps.contactsPermissionGranted,
        scope = deps.scope,
        state = agentContactLookupState,
        callbacks = AssistantAgentContactLookupCallbacks(
            onContactsPermissionGrantedChange = { deps.permissionOverlayState.contactsPermissionGranted = it },
            onLaunchContactsPermission = { contactPermissionLaunchers.agentContacts.launch(it) },
            onAgentLookupContactResult = deps.assistantViewModel::onAgentLookupContactResult,
            onAgentLookupDeviceContactsResolved = { results, echoText, pendingSelection ->
                deps.assistantViewModel.onAgentLookupDeviceContactsResolved(
                    results = results,
                    echoText = echoText,
                    pendingSelection = pendingSelection
                )
            }
        )
    )

    return AssistantRootContactPermissionRuntime(
        launchers = contactPermissionLaunchers
    )
}

private fun Context.hasContactsPermission(): Boolean =
    ContextCompat.checkSelfPermission(
        this,
        Manifest.permission.READ_CONTACTS
    ) == PackageManager.PERMISSION_GRANTED

private fun Context.shouldShowContactsPermissionRationale(): Boolean =
    findActivity()?.let {
        ActivityCompat.shouldShowRequestPermissionRationale(
            it,
            Manifest.permission.READ_CONTACTS
        )
    } ?: true

private fun Context.applicationDetailsSettingsIntent(): Intent =
    Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.fromParts("package", packageName, null)
    )

private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return current as? Activity
}

private const val CONTACT_PERMISSION_LOG_TAG = "CONTACT_PERMISSION"
