package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class AssistantOverlayPermissionActionState(
    val networkMode: V88NetworkMode
)

internal data class AssistantOverlayPermissionActionCallbacks(
    val onShowMessage: (String) -> Unit,
    val onShowNetworkBlockerChange: (Boolean) -> Unit,
    val onRequestedPermissionNameChange: (String?) -> Unit,
    val onPendingPermissionActionChange: (String) -> Unit,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onStoragePermissionGrantedChange: (Boolean) -> Unit,
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val onPhonePermissionGrantedChange: (Boolean) -> Unit,
    val onLaunchContactsPermission: () -> Unit,
    val onRunPendingPermissionAction: () -> Unit,
    val onGoHomeAfterContactsDenied: () -> Unit
)

internal data class AssistantPendingPermissionActionCallbacks(
    val onRunDial: () -> Unit,
    val onRunTranslationDial: () -> Unit,
    val onRunContactCall: () -> Unit,
    val onConfirmAttachmentUploaded: () -> Unit
)

internal fun handleOverlayNetworkRetry(
    state: AssistantOverlayPermissionActionState,
    callbacks: AssistantOverlayPermissionActionCallbacks
) {
    if (state.networkMode == V88NetworkMode.Offline) {
        callbacks.onShowMessage(
            currentAppText(
                "当前仍为断网模拟，可在开发者功能切换",
                "Offline simulation is still enabled. Change it in Developer Tools."
            )
        )
    } else {
        callbacks.onShowNetworkBlockerChange(false)
    }
}

internal fun handleOverlayPermissionAllow(
    permission: V88PermissionKind,
    callbacks: AssistantOverlayPermissionActionCallbacks
) {
    when (permission) {
        V88PermissionKind.Microphone -> callbacks.onMicrophonePermissionGrantedChange(true)
        V88PermissionKind.Storage -> callbacks.onStoragePermissionGrantedChange(true)
        V88PermissionKind.Contacts -> {
            callbacks.onRequestedPermissionNameChange(null)
            callbacks.onLaunchContactsPermission()
            return
        }
        V88PermissionKind.Phone -> callbacks.onPhonePermissionGrantedChange(true)
    }
    callbacks.onRequestedPermissionNameChange(null)
    callbacks.onRunPendingPermissionAction()
}

internal fun handleOverlayPermissionDeny(
    permission: V88PermissionKind,
    callbacks: AssistantOverlayPermissionActionCallbacks
) {
    callbacks.onShowMessage(
        currentAppText(
            "需要${permission.title}才能使用此功能",
            "${permission.englishTitle()} permission is required for this feature"
        )
    )
    callbacks.onRequestedPermissionNameChange(null)
    callbacks.onPendingPermissionActionChange("")
}

private fun V88PermissionKind.englishTitle(): String =
    when (this) {
        V88PermissionKind.Microphone -> "Microphone"
        V88PermissionKind.Storage -> "Storage"
        V88PermissionKind.Contacts -> "Contacts"
        V88PermissionKind.Phone -> "Phone"
    }

internal fun runAssistantPendingPermissionAction(
    action: String,
    callbacks: AssistantPendingPermissionActionCallbacks
): Boolean {
    return when (action) {
        "dial" -> {
            callbacks.onRunDial()
            true
        }
        "translation_dial" -> {
            callbacks.onRunTranslationDial()
            true
        }
        "contact_call" -> {
            callbacks.onRunContactCall()
            true
        }
        "upload_attachment" -> {
            callbacks.onConfirmAttachmentUploaded()
            true
        }
        "open_contacts" -> false
        else -> false
    }
}
