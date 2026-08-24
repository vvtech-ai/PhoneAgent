package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal const val AssistantAgentPermissionGrantedStatus = "OK"
internal const val AssistantAgentPermissionDeniedStatus = "DENIED"
internal const val AssistantAgentPermissionGrantedMessage = "授权成功"
internal const val AssistantAgentPermissionDeniedMessage = "用户拒绝授权"
internal const val AssistantTranslationAudioPermissionDeniedMessage = "请授予麦克风权限后再使用实时翻译通话"

internal fun localizedAssistantAgentPermissionMessage(granted: Boolean): String =
    if (granted) {
        currentAppText(AssistantAgentPermissionGrantedMessage, "Permission granted")
    } else {
        currentAppText(AssistantAgentPermissionDeniedMessage, "Permission denied")
    }

internal fun localizedAssistantTranslationAudioPermissionDeniedMessage(): String =
    currentAppText(
        AssistantTranslationAudioPermissionDeniedMessage,
        "Allow microphone access before using live translation calls"
    )

internal data class AssistantAgentPermissionLauncherResultCallbacks(
    val consumeAgentPermissionRequest: () -> PermissionRequestPayload?,
    val isAgentPermissionGranted: (PermissionRequestPayload) -> Boolean,
    val onAgentPermissionResult: (
        request: PermissionRequestPayload,
        status: String,
        granted: Boolean,
        message: String
    ) -> Unit
)

internal fun handleAssistantAgentPermissionLauncherResult(
    callbacks: AssistantAgentPermissionLauncherResultCallbacks
) {
    val request = callbacks.consumeAgentPermissionRequest() ?: return
    val granted = callbacks.isAgentPermissionGranted(request)
    callbacks.onAgentPermissionResult(
        request,
        if (granted) AssistantAgentPermissionGrantedStatus else AssistantAgentPermissionDeniedStatus,
        granted,
        localizedAssistantAgentPermissionMessage(granted)
    )
}

internal data class AssistantAgentDocumentLauncherResultCallbacks<T : Any>(
    val onClearAgentDocumentRequest: () -> Unit,
    val onAgentDocumentPickerCancelled: () -> Unit,
    val onAgentDocumentPicked: (T) -> Unit
)

internal fun <T : Any> handleAssistantAgentDocumentLauncherResult(
    uri: T?,
    callbacks: AssistantAgentDocumentLauncherResultCallbacks<T>
) {
    callbacks.onClearAgentDocumentRequest()
    if (uri == null) {
        callbacks.onAgentDocumentPickerCancelled()
    } else {
        callbacks.onAgentDocumentPicked(uri)
    }
}

internal data class AssistantVoiceCloneAudioPermissionResultCallbacks(
    val onVoiceCloneAudioPermissionResult: (Boolean) -> Unit
)

internal fun handleAssistantVoiceCloneAudioPermissionResult(
    granted: Boolean,
    callbacks: AssistantVoiceCloneAudioPermissionResultCallbacks
) {
    callbacks.onVoiceCloneAudioPermissionResult(granted)
}

internal data class AssistantTranslationAudioPermissionResultCallbacks(
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onAudioPermissionGranted: () -> Unit,
    val onShowMessage: (String) -> Unit
)

internal fun handleAssistantTranslationAudioPermissionResult(
    granted: Boolean,
    callbacks: AssistantTranslationAudioPermissionResultCallbacks
) {
    callbacks.onMicrophonePermissionGrantedChange(granted)
    if (granted) {
        callbacks.onAudioPermissionGranted()
    } else {
        callbacks.onShowMessage(localizedAssistantTranslationAudioPermissionDeniedMessage())
    }
}

internal data class AssistantStartupPermissionsResultCallbacks(
    val onLoadLocationIfPermitted: () -> Unit,
    val onTrustedCalleeStartupReadyChange: (Boolean) -> Unit
)

internal fun handleAssistantStartupPermissionsResult(
    grantResults: Map<String, Boolean>,
    callbacks: AssistantStartupPermissionsResultCallbacks
) {
    if (grantResults[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
        grantResults[Manifest.permission.ACCESS_COARSE_LOCATION] == true
    ) {
        callbacks.onLoadLocationIfPermitted()
    }
    callbacks.onTrustedCalleeStartupReadyChange(true)
}
