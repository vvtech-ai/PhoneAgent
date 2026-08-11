package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.network.hasValidatedInternetAccess

internal fun shouldBlockAssistantOnlineEntry(
    networkMode: V88NetworkMode,
    hasValidatedInternet: Boolean
): Boolean = networkMode == V88NetworkMode.Offline || !hasValidatedInternet

internal fun blockAssistantRootIfOffline(
    deps: AssistantRootActionGraphDeps
): Boolean {
    val permissionOverlay = deps.runtimeGraph.state.permissionOverlay
    val shouldBlock = shouldBlockAssistantOnlineEntry(
        networkMode = permissionOverlay.networkMode,
        hasValidatedInternet = deps.context.hasValidatedInternetAccess()
    )
    if (!shouldBlock) return false
    permissionOverlay.showNetworkBlocker()
    return true
}
