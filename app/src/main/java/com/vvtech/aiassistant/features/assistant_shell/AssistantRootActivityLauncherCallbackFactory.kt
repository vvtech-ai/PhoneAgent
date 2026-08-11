package com.vvtech.aiassistant.features.assistant_shell

import android.net.Uri
import com.vvtech.aiassistant.core.model.PermissionRequestPayload

internal data class AssistantRootActivityLauncherCallbackFactoryDeps(
    val consumeAgentPermissionRequest: () -> PermissionRequestPayload?,
    val isAgentPermissionGranted: (PermissionRequestPayload) -> Boolean,
    val onAgentPermissionResult: (
        request: PermissionRequestPayload,
        status: String,
        granted: Boolean,
        message: String
    ) -> Unit,
    val onClearAgentDocumentRequest: () -> Unit,
    val onAgentDocumentPickerCancelled: () -> Unit,
    val onAgentDocumentPicked: (Uri) -> Unit,
    val onVoiceCloneAudioPermissionResult: (Boolean) -> Unit,
    val onMicrophonePermissionGrantedChange: (Boolean) -> Unit,
    val onTranslationAudioPermissionGranted: () -> Unit,
    val onShowMessage: (String) -> Unit,
    val onLoadLocationIfPermitted: () -> Unit,
    val onTrustedCalleeStartupReadyChange: (Boolean) -> Unit
)

internal fun buildAssistantRootActivityLauncherCallbacks(
    deps: AssistantRootActivityLauncherCallbackFactoryDeps
): AssistantRootActivityLauncherCallbacks =
    AssistantRootActivityLauncherCallbacks(
        onAgentPermissionResult = {
            handleAssistantAgentPermissionLauncherResult(
                AssistantAgentPermissionLauncherResultCallbacks(
                    consumeAgentPermissionRequest = deps.consumeAgentPermissionRequest,
                    isAgentPermissionGranted = deps.isAgentPermissionGranted,
                    onAgentPermissionResult = deps.onAgentPermissionResult
                )
            )
        },
        onAgentDocumentResult = { uri ->
            handleAssistantAgentDocumentLauncherResult(
                uri = uri,
                callbacks = AssistantAgentDocumentLauncherResultCallbacks(
                    onClearAgentDocumentRequest = deps.onClearAgentDocumentRequest,
                    onAgentDocumentPickerCancelled = deps.onAgentDocumentPickerCancelled,
                    onAgentDocumentPicked = deps.onAgentDocumentPicked
                )
            )
        },
        onVoiceCloneAudioPermissionResult = { granted ->
            handleAssistantVoiceCloneAudioPermissionResult(
                granted = granted,
                callbacks = AssistantVoiceCloneAudioPermissionResultCallbacks(
                    onVoiceCloneAudioPermissionResult = deps.onVoiceCloneAudioPermissionResult
                )
            )
        },
        onTranslationCallAudioPermissionResult = { granted ->
            handleAssistantTranslationAudioPermissionResult(
                granted = granted,
                callbacks = AssistantTranslationAudioPermissionResultCallbacks(
                    onMicrophonePermissionGrantedChange = deps.onMicrophonePermissionGrantedChange,
                    onAudioPermissionGranted = deps.onTranslationAudioPermissionGranted,
                    onShowMessage = deps.onShowMessage
                )
            )
        },
        onStartupPermissionsResult = { grantResults ->
            handleAssistantStartupPermissionsResult(
                grantResults = grantResults,
                callbacks = AssistantStartupPermissionsResultCallbacks(
                    onLoadLocationIfPermitted = deps.onLoadLocationIfPermitted,
                    onTrustedCalleeStartupReadyChange = deps.onTrustedCalleeStartupReadyChange
                )
            )
        }
    )
