package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.vvtech.aiassistant.core.model.PermissionRequestPayload

internal class AssistantAgentPermissionEffectArgs(
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
internal fun FinalAgentPermissionEffect(args: AssistantAgentPermissionEffectArgs) {
    LaunchedEffect(args.agentPermissionRequest, args.agentPendingToolCallId) {
        val request = args.agentPermissionRequest ?: return@LaunchedEffect
        val androidPermission = request.androidPermission
        if (androidPermission.isNullOrBlank()) {
            val status = if (args.isAgentPermissionGranted(request)) "OK" else "SETTINGS_REQUIRED"
            args.onAgentPermissionResult(
                request.permissionKey,
                androidPermission,
                status,
                status == "OK",
                if (status == "OK") "授权能力可用" else "该权限需要到系统设置中开启"
            )
            return@LaunchedEffect
        }
        if (args.isAgentPermissionGranted(request)) {
            args.onAgentPermissionResult(
                request.permissionKey,
                androidPermission,
                "OK",
                true,
                "权限已授权"
            )
        } else {
            request.reason?.takeIf { it.isNotBlank() }?.let { reason ->
                Toast.makeText(args.context, reason, Toast.LENGTH_SHORT).show()
            }
            args.onActiveAgentPermissionRequestChange(request)
            args.onLaunchPermission(androidPermission)
        }
    }
}
