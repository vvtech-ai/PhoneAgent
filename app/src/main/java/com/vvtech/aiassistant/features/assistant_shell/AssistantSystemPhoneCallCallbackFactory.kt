package com.vvtech.aiassistant.features.assistant_shell

import android.content.Context
import android.widget.Toast

internal data class AssistantSystemPhoneCallCallbackFactoryDeps(
    val context: Context,
    val callDialState: AssistantCallDialState,
    val permissionOverlayState: AssistantPermissionOverlayState,
    val systemPhoneCallState: AssistantSystemPhoneCallState,
    val clearTranslationRuntime: () -> Unit,
    val onSystemPhoneCallStarted: (AssistantSystemPhoneCallUiPlan) -> Unit = {}
)

internal fun buildAssistantSystemPhoneCallCallbacks(
    deps: AssistantSystemPhoneCallCallbackFactoryDeps,
    onLaunchCallPhonePermission: (String) -> Unit = {}
): AssistantSystemPhoneCallActionCallbacks = AssistantSystemPhoneCallActionCallbacks(
    onPrepareNormalCallAttempt = {
        deps.callDialState.dialer.translateEnabled = false
        deps.clearTranslationRuntime()
    },
    onPrepareSystemPhoneCallUi = { plan ->
        deps.callDialState.dialer.lastDialedNumber = plan.normalizedNumber
        deps.callDialState.normalCallSeconds = 0
        deps.callDialState.normalCallMuted = false
        deps.callDialState.normalCallSpeaker = true
        deps.callDialState.dialer.translateEnabled = false
        deps.callDialState.normalCallReturnPage = plan.returnPageName
    },
    onPhonePermissionGrantedChange = { deps.permissionOverlayState.phonePermissionGranted = it },
    onSetPendingCall = deps.systemPhoneCallState::setPending,
    onLaunchCallPhonePermission = onLaunchCallPhonePermission,
    onSystemPhoneCallStarted = deps.onSystemPhoneCallStarted,
    onShowMessage = { message ->
        Toast.makeText(deps.context, message, Toast.LENGTH_SHORT).show()
    }
)
