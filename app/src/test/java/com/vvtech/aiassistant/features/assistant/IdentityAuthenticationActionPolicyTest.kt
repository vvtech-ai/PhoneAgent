package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IdentityAuthenticationActionPolicyTest {

    @Test
    fun `authentication action is available only before identity is verified`() {
        assertTrue(shouldShowIdentityAuthentication(UserIdentityDisplayStatus.EMPTY))
        assertTrue(shouldShowIdentityAuthentication(UserIdentityDisplayStatus.FILLED))
        assertFalse(shouldShowIdentityAuthentication(UserIdentityDisplayStatus.VERIFIED))
    }
}
