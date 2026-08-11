package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.features.assistant.AssistantAgentLookupContactEffectArgs
import com.vvtech.aiassistant.features.assistant.AssistantAgentLookupDeviceContactsEffectArgs
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.FinalAgentLookupContactEffect
import com.vvtech.aiassistant.features.assistant.FinalAgentLookupDeviceContactsEffect
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.CoroutineScope

internal class AssistantAgentContactLookupState {
    internal var permissionRetry by mutableStateOf(0)
        private set

    internal var permissionAskedKey by mutableStateOf<String?>(null)
        private set

    fun markPermissionRetry() {
        permissionRetry++
    }

    internal fun updatePermissionAskedKey(value: String?) {
        permissionAskedKey = value
    }
}

@Composable
internal fun rememberAssistantAgentContactLookupState(): AssistantAgentContactLookupState {
    return remember { AssistantAgentContactLookupState() }
}

internal class AssistantAgentContactLookupCallbacks(
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val onLaunchContactsPermission: (String) -> Unit,
    val onAgentLookupContactResult: (Map<String, Any?>) -> Unit,
    val onAgentLookupDeviceContactsResolved: (
        results: List<Map<String, Any?>>,
        echoText: String?,
        pendingSelection: DeviceContactSelectionUiState?
    ) -> Unit
)

@Composable
internal fun AssistantAgentContactLookupEffects(
    context: Context,
    assistantUiState: Index9AssistantUiState,
    contactsPermissionGranted: Boolean,
    scope: CoroutineScope,
    state: AssistantAgentContactLookupState,
    callbacks: AssistantAgentContactLookupCallbacks
) {
    val deviceContactResolver = remember(context) { DeviceContactResolver(context) }

    FinalAgentLookupContactEffect(
        AssistantAgentLookupContactEffectArgs(
            context = context,
            assistantUiState = assistantUiState,
            agentContactsPermissionRetry = state.permissionRetry,
            contactsPermissionGranted = contactsPermissionGranted,
            onContactsPermissionGrantedChange = callbacks.onContactsPermissionGrantedChange,
            agentContactsPermissionAskedKey = state.permissionAskedKey,
            onAgentContactsPermissionAskedKeyChange = state::updatePermissionAskedKey,
            onLaunchContactsPermission = callbacks.onLaunchContactsPermission,
            scope = scope,
            deviceContactResolver = deviceContactResolver,
            onAgentLookupContactResult = callbacks.onAgentLookupContactResult
        )
    )

    FinalAgentLookupDeviceContactsEffect(
        AssistantAgentLookupDeviceContactsEffectArgs(
            context = context,
            assistantUiState = assistantUiState,
            agentContactsPermissionRetry = state.permissionRetry,
            contactsPermissionGranted = contactsPermissionGranted,
            onContactsPermissionGrantedChange = callbacks.onContactsPermissionGrantedChange,
            agentContactsPermissionAskedKey = state.permissionAskedKey,
            onAgentContactsPermissionAskedKeyChange = state::updatePermissionAskedKey,
            onLaunchContactsPermission = callbacks.onLaunchContactsPermission,
            scope = scope,
            deviceContactResolver = deviceContactResolver,
            onAgentLookupDeviceContactsResolved = callbacks.onAgentLookupDeviceContactsResolved
        )
    )
}
