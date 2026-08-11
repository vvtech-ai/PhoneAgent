package com.vvtech.aiassistant.features.assistant_calls

internal enum class DialerPermissionSequenceAction {
    WAIT_FOR_LOCATION,
    REQUEST_CALL_LOG,
    LOAD_CALL_LOG,
    NONE
}

internal fun nextDialerPermissionAction(
    locationDecisionComplete: Boolean,
    callLogPermissionGranted: Boolean,
    callLogPermissionRequested: Boolean
): DialerPermissionSequenceAction = when {
    !locationDecisionComplete -> DialerPermissionSequenceAction.WAIT_FOR_LOCATION
    callLogPermissionGranted -> DialerPermissionSequenceAction.LOAD_CALL_LOG
    !callLogPermissionRequested -> DialerPermissionSequenceAction.REQUEST_CALL_LOG
    else -> DialerPermissionSequenceAction.NONE
}
