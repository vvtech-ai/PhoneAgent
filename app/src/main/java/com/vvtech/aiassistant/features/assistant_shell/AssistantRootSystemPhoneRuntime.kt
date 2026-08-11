package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import androidx.activity.result.ActivityResultLauncher
import androidx.compose.runtime.Composable

internal data class AssistantRootSystemPhoneRuntimeDeps(
    val context: Context,
    val callDialState: AssistantCallDialState,
    val permissionOverlayState: AssistantPermissionOverlayState,
    val systemPhoneCallState: AssistantSystemPhoneCallState,
    val clearTranslationRuntime: () -> Unit,
    val onSystemPhoneCallStarted: (AssistantSystemPhoneCallUiPlan) -> Unit = {}
)

internal data class AssistantRootSystemPhoneRuntimeCallbacks(
    val onPermissionDenied: () -> Unit
)

internal class AssistantRootSystemPhoneRuntime(
    val callPhonePermissionLauncher: ActivityResultLauncher<String>,
    private val callbacksProvider: ((String) -> Unit) -> AssistantSystemPhoneCallActionCallbacks
) {
    fun systemPhoneCallCallbacks(
        onLaunchCallPhonePermission: (String) -> Unit = {}
    ): AssistantSystemPhoneCallActionCallbacks = callbacksProvider(onLaunchCallPhonePermission)
}

@Composable
internal fun rememberAssistantRootSystemPhoneRuntime(
    deps: AssistantRootSystemPhoneRuntimeDeps,
    callbacks: AssistantRootSystemPhoneRuntimeCallbacks
): AssistantRootSystemPhoneRuntime {
    val systemPhoneCallCallbackDeps = AssistantSystemPhoneCallCallbackFactoryDeps(
        context = deps.context,
        callDialState = deps.callDialState,
        permissionOverlayState = deps.permissionOverlayState,
        systemPhoneCallState = deps.systemPhoneCallState,
        clearTranslationRuntime = deps.clearTranslationRuntime,
        onSystemPhoneCallStarted = deps.onSystemPhoneCallStarted
    )

    fun systemPhoneCallCallbacks(
        onLaunchCallPhonePermission: (String) -> Unit = {}
    ): AssistantSystemPhoneCallActionCallbacks =
        buildAssistantSystemPhoneCallCallbacks(
            deps = systemPhoneCallCallbackDeps,
            onLaunchCallPhonePermission = onLaunchCallPhonePermission
        )

    fun executeSystemPhoneCall(target: String, source: String) {
        executeAssistantSystemPhoneCall(
            context = deps.context,
            target = target,
            source = source,
            callbacks = systemPhoneCallCallbacks()
        )
    }

    val callPhonePermissionLauncher = rememberAssistantSystemPhonePermissionLauncher(
        state = deps.systemPhoneCallState,
        callbacks = AssistantSystemPhonePermissionCallbacks(
            onPhonePermissionGrantedChange = { deps.permissionOverlayState.phonePermissionGranted = it },
            onExecuteSystemPhoneCall = ::executeSystemPhoneCall,
            onPermissionDenied = callbacks.onPermissionDenied
        )
    )

    return AssistantRootSystemPhoneRuntime(
        callPhonePermissionLauncher = callPhonePermissionLauncher,
        callbacksProvider = ::systemPhoneCallCallbacks
    )
}
