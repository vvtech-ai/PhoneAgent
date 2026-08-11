package com.vvtech.aiassistant.features.assistant_shell

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable

internal class AssistantSystemPhoneCallState(
    private val pendingNumberState: MutableState<String>,
    private val pendingSourceState: MutableState<String>
) {
    fun setPending(number: String, source: String) {
        pendingNumberState.value = number
        pendingSourceState.value = source
    }

    fun clearPending() {
        pendingNumberState.value = ""
        pendingSourceState.value = ""
    }

    internal fun takePending(): Pair<String, String> {
        val number = pendingNumberState.value
        val source = pendingSourceState.value
        clearPending()
        return number to source
    }
}

@Composable
internal fun rememberAssistantSystemPhoneCallState(): AssistantSystemPhoneCallState {
    val pendingNumber = rememberSaveable { mutableStateOf("") }
    val pendingSource = rememberSaveable { mutableStateOf("") }
    return remember(pendingNumber, pendingSource) {
        AssistantSystemPhoneCallState(pendingNumber, pendingSource)
    }
}

internal class AssistantSystemPhonePermissionCallbacks(
    val onPhonePermissionGrantedChange: (Boolean) -> Unit,
    val onExecuteSystemPhoneCall: (String, String) -> Unit,
    val onPermissionDenied: () -> Unit
)

@Composable
internal fun rememberAssistantSystemPhonePermissionLauncher(
    state: AssistantSystemPhoneCallState,
    callbacks: AssistantSystemPhonePermissionCallbacks
): ActivityResultLauncher<String> {
    return rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        callbacks.onPhonePermissionGrantedChange(granted)
        val (target, source) = state.takePending()
        if (granted && target.isNotBlank()) {
            callbacks.onExecuteSystemPhoneCall(target, source)
        } else if (target.isNotBlank()) {
            callbacks.onPermissionDenied()
        }
    }
}
