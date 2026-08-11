package com.vvtech.aiassistant.account

import android.app.Application
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class AccountIdentityProviderTest {

    private val context = RuntimeEnvironment.getApplication()

    @After
    fun tearDown() {
        AccountIdentityProvider.signOut(context)
    }

    @Test
    fun `stores voice clone token with login and clears it on logout`() {
        AccountIdentityProvider.signIn(
            context,
            "13800138000",
            "access-token",
            "refresh-token",
            "signed-token"
        )

        assertEquals("signed-token", AccountIdentityProvider.voiceCloneAccessToken)

        AccountIdentityProvider.signOut(context)

        assertTrue(AccountIdentityProvider.voiceCloneAccessToken.isBlank())
    }
}
