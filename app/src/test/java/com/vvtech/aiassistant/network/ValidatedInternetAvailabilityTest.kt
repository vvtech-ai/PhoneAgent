package com.vvtech.aiassistant.network

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ValidatedInternetAvailabilityTest {
    @Test
    fun requiresInternetAndValidatedCapabilities() {
        assertTrue(
            hasValidatedInternetCapabilities(
                hasInternetCapability = true,
                hasValidatedCapability = true
            )
        )
        assertFalse(
            hasValidatedInternetCapabilities(
                hasInternetCapability = true,
                hasValidatedCapability = false
            )
        )
        assertFalse(
            hasValidatedInternetCapabilities(
                hasInternetCapability = false,
                hasValidatedCapability = true
            )
        )
    }
}
