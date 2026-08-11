package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.compose.runtime.Composable

@Composable
internal fun rememberAssistantRootDialSystemPhoneCoordinator(
    context: Context,
    callDialState: AssistantCallDialState,
    permissionOverlayState: AssistantPermissionOverlayState,
    systemPhoneCallState: AssistantSystemPhoneCallState,
    callRecordState: AssistantCallRecordState,
    activeAccountId: () -> String,
    clearTranslationRuntime: () -> Unit,
    onPermissionDenied: () -> Unit
): AssistantRootSystemPhoneRuntime {
    return rememberAssistantRootSystemPhoneRuntime(
        deps = AssistantRootSystemPhoneRuntimeDeps(
            context = context,
            callDialState = callDialState,
            permissionOverlayState = permissionOverlayState,
            systemPhoneCallState = systemPhoneCallState,
            clearTranslationRuntime = clearTranslationRuntime,
            onSystemPhoneCallStarted = { plan ->
                callRecordState.appendForAccount(
                    activeAccountId(),
                    buildSystemPhoneCallRecord(plan)
                )
                callDialState.showCallsDialSheet = true
            }
        ),
        callbacks = AssistantRootSystemPhoneRuntimeCallbacks(
            onPermissionDenied = onPermissionDenied
        )
    )
}
