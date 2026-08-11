package com.vvtech.aiassistant.features.assistant_shell

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable

internal class AssistantRootActivityLaunchers(
    val agentPermission: ActivityResultLauncher<String>,
    val agentDocument: ActivityResultLauncher<Array<String>>,
    val voiceCloneAudioPermission: ActivityResultLauncher<String>,
    val translationCallAudioPermission: ActivityResultLauncher<String>,
    val startupPermissions: ActivityResultLauncher<Array<String>>
)

internal data class AssistantRootActivityLauncherCallbacks(
    val onAgentPermissionResult: () -> Unit,
    val onAgentDocumentResult: (Uri?) -> Unit,
    val onVoiceCloneAudioPermissionResult: (Boolean) -> Unit,
    val onTranslationCallAudioPermissionResult: (Boolean) -> Unit,
    val onStartupPermissionsResult: (Map<String, Boolean>) -> Unit
)

@Composable
internal fun rememberAssistantRootActivityLaunchers(
    callbacks: AssistantRootActivityLauncherCallbacks
): AssistantRootActivityLaunchers {
    val agentPermission = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) {
        callbacks.onAgentPermissionResult()
    }
    val agentDocument = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
        onResult = callbacks.onAgentDocumentResult
    )
    val voiceCloneAudioPermission = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = callbacks.onVoiceCloneAudioPermissionResult
    )
    val translationCallAudioPermission = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = callbacks.onTranslationCallAudioPermissionResult
    )
    val startupPermissions = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
        onResult = callbacks.onStartupPermissionsResult
    )

    return AssistantRootActivityLaunchers(
        agentPermission = agentPermission,
        agentDocument = agentDocument,
        voiceCloneAudioPermission = voiceCloneAudioPermission,
        translationCallAudioPermission = translationCallAudioPermission,
        startupPermissions = startupPermissions
    )
}
