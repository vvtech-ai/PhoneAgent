package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Test

class DialerPermissionSequencePolicyTest {
    @Test
    fun `waits for location decision before requesting call log`() {
        assertEquals(
            DialerPermissionSequenceAction.WAIT_FOR_LOCATION,
            nextDialerPermissionAction(
                locationDecisionComplete = false,
                callLogPermissionGranted = false,
                callLogPermissionRequested = false
            )
        )
    }

    @Test
    fun `requests call log after location is granted declined or deferred`() {
        assertEquals(
            DialerPermissionSequenceAction.REQUEST_CALL_LOG,
            nextDialerPermissionAction(
                locationDecisionComplete = true,
                callLogPermissionGranted = false,
                callLogPermissionRequested = false
            )
        )
    }

    @Test
    fun `loads records when granted and does not reprompt after denial`() {
        assertEquals(
            DialerPermissionSequenceAction.LOAD_CALL_LOG,
            nextDialerPermissionAction(
                locationDecisionComplete = true,
                callLogPermissionGranted = true,
                callLogPermissionRequested = true
            )
        )
        assertEquals(
            DialerPermissionSequenceAction.NONE,
            nextDialerPermissionAction(
                locationDecisionComplete = true,
                callLogPermissionGranted = false,
                callLogPermissionRequested = true
            )
        )
    }
}
