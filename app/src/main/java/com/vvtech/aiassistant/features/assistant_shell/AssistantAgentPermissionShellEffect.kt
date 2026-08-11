package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.AssistantAgentPermissionEffectArgs
import com.vvtech.aiassistant.features.assistant.FinalAgentPermissionEffect

internal data class AssistantAgentPermissionShellEffectArgs(
    val context: Context,
    val agentPermissionRequest: PermissionRequestPayload?,
    val agentPendingToolCallId: String?,
    val isAgentPermissionGranted: (PermissionRequestPayload) -> Boolean,
    val onAgentPermissionResult: (
        permissionKey: String,
        androidPermission: String?,
        status: String,
        granted: Boolean,
        message: String
    ) -> Unit,
    val onActiveAgentPermissionRequestChange: (PermissionRequestPayload?) -> Unit,
    val onLaunchPermission: (String) -> Unit
)

@Composable
internal fun AssistantAgentPermissionShellEffect(args: AssistantAgentPermissionShellEffectArgs) {
    FinalAgentPermissionEffect(
        AssistantAgentPermissionEffectArgs(
            context = args.context,
            agentPermissionRequest = args.agentPermissionRequest,
            agentPendingToolCallId = args.agentPendingToolCallId,
            isAgentPermissionGranted = args.isAgentPermissionGranted,
            onAgentPermissionResult = args.onAgentPermissionResult,
            onActiveAgentPermissionRequestChange = args.onActiveAgentPermissionRequestChange,
            onLaunchPermission = args.onLaunchPermission
        )
    )
}
