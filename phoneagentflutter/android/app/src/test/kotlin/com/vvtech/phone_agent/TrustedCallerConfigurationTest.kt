package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test
import com.vvtech.aiassistant.BuildConfig

/** Exercise the selected root Properties input without exposing credential values. */
class TrustedCallerConfigurationTest {
    @Test
    fun onlySelectedSdkEnvironmentResolvesNonemptyCredentials() {
        val environment = BuildConfig.TRUSTED_CALLER_ENVIRONMENT
        val selected = TrustedCallerConfiguration.read(environment)
        assertNotNull("Provide root trusted Properties before verification", selected)
        assertTrue(selected!!.getValue("appKey").isNotBlank())
        assertTrue(selected.getValue("appSecret").isNotBlank())
        assertNull(TrustedCallerConfiguration.read(if (environment == "test") "pro" else "test"))
    }

    @Test
    fun unknownEnvironmentRemainsRejected() {
        assertNull(TrustedCallerConfiguration.read("unknown"))
        assertNull(TrustedCallerConfiguration.read(""))
    }
}
