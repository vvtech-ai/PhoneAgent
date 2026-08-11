package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.V88PermissionKind

internal enum class AssistantPermissionDialogPresentation {
    Contact,
    Legacy
}

internal fun assistantPermissionDialogPresentation(
    permission: V88PermissionKind
): AssistantPermissionDialogPresentation =
    if (permission == V88PermissionKind.Contacts) {
        AssistantPermissionDialogPresentation.Contact
    } else {
        AssistantPermissionDialogPresentation.Legacy
    }
