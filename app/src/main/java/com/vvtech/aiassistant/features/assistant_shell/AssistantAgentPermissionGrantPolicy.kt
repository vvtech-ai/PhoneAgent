package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.core.model.PermissionRequestPayload

internal data class AssistantAgentPermissionCheckPlan(
    val alwaysGranted: Boolean,
    val androidPermissions: List<String>
)

internal fun assistantAgentPermissionCheckPlan(
    request: PermissionRequestPayload
): AssistantAgentPermissionCheckPlan {
    return when (request.permissionKey) {
        "location" -> AssistantAgentPermissionCheckPlan(
            alwaysGranted = false,
            androidPermissions = listOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )
        "document_picker" -> AssistantAgentPermissionCheckPlan(
            alwaysGranted = true,
            androidPermissions = emptyList()
        )
        else -> AssistantAgentPermissionCheckPlan(
            alwaysGranted = false,
            androidPermissions = request.androidPermission
                ?.takeIf { it.isNotBlank() }
                ?.let(::listOf)
                .orEmpty()
        )
    }
}

internal fun isAssistantAgentPermissionGranted(
    context: Context,
    request: PermissionRequestPayload
): Boolean {
    val plan = assistantAgentPermissionCheckPlan(request)
    if (plan.alwaysGranted) return true
    return plan.androidPermissions.any { permission ->
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }
}
