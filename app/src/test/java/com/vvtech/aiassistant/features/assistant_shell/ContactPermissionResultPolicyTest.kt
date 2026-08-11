package com.vvtech.aiassistant.features.assistant_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class ContactPermissionResultPolicyTest {
    @Test
    fun grantedPermissionOpensContacts() {
        assertEquals(
            ContactPermissionResultAction.OPEN_CONTACTS,
            resolveContactPermissionResult(granted = true, shouldShowRationale = false)
        )
    }

    @Test
    fun ordinaryDenialShowsRetryMessage() {
        assertEquals(
            ContactPermissionResultAction.SHOW_RETRY_MESSAGE,
            resolveContactPermissionResult(granted = false, shouldShowRationale = true)
        )
    }

    @Test
    fun permanentDenialGuidesUserToSystemSettings() {
        assertEquals(
            ContactPermissionResultAction.OPEN_APP_SETTINGS,
            resolveContactPermissionResult(granted = false, shouldShowRationale = false)
        )
    }
}
