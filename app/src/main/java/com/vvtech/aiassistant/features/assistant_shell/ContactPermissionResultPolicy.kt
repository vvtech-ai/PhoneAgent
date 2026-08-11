package com.vvtech.aiassistant.features.assistant_shell

internal enum class ContactPermissionResultAction {
    OPEN_CONTACTS,
    SHOW_RETRY_MESSAGE,
    OPEN_APP_SETTINGS
}

internal fun resolveContactPermissionResult(
    granted: Boolean,
    shouldShowRationale: Boolean
): ContactPermissionResultAction = when {
    granted -> ContactPermissionResultAction.OPEN_CONTACTS
    shouldShowRationale -> ContactPermissionResultAction.SHOW_RETRY_MESSAGE
    else -> ContactPermissionResultAction.OPEN_APP_SETTINGS
}
