package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class TrustedCallerEnvironmentTest {
    @Test fun registeredIdentitiesIncludeTestRelease() {
        assertEquals("test", TrustedCallerEnvironment.resolve("com.vvtech.aiassistant.test", false))
        assertEquals("test", TrustedCallerEnvironment.resolve("com.vvtech.aiassistant.test", true))
        assertEquals("test", TrustedCallerEnvironment.resolve("com.vvtech.aiassistant.dev", false))
        assertEquals("test", TrustedCallerEnvironment.resolve("com.vvtech.aiassistant.dev", true))
        assertEquals("pro", TrustedCallerEnvironment.resolve("com.vvtech.aiassistant", false))
        assertEquals("test", TrustedCallerEnvironment.resolve("com.vvtech.aiassistant", true))
        assertEquals("unavailable", TrustedCallerEnvironment.resolve("unregistered.test", false))
        assertEquals("unavailable", TrustedCallerEnvironment.resolve("unregistered", true))
    }
}
