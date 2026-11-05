package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class TrustedCallerAccountOwnerTest {
    private val fields = mapOf("accountId" to "synthetic-account", "phone" to "synthetic-phone", "loginEpoch" to 3)

    @Test fun acceptsOnlyCompleteIntegerAccountMetadata() {
        val owner = TrustedCallerAccountOwner.parse(fields, "test")!!
        assertEquals(3L, owner.loginEpoch)
        for ((key, value) in listOf("accountId" to "", "phone" to "synthetic\u007fphone",
            "loginEpoch" to -1, "loginEpoch" to 3.0, "loginEpoch" to true)) {
            assertNull(TrustedCallerAccountOwner.parse(fields + (key to value), "test"))
        }
        assertNull(TrustedCallerAccountOwner.parse(fields + ("authorized" to true), "test"))
        assertNull(TrustedCallerAccountOwner.parse(fields, "unknown"))
        assertNull(TrustedCallerAccountOwner.parse(fields - "phone", "test"))
    }

    @Test fun surfaceTokenIsIndependentButAccountTupleMustMatch() {
        val owner = TrustedCallerAccountOwner.parse(fields, "test")!!
        val surface = TrustedCallerSurface("a".repeat(32), owner.accountId, owner.phone, owner.loginEpoch, owner.environment)
        assertTrue(owner.matches(surface))
        assertTrue(owner.matches(surface.copy(token = "b".repeat(32))))
        assertFalse(owner.matches(surface.copy(phone = "other")))
        assertFalse(owner.matches(surface.copy(loginEpoch = 4)))
        assertFalse(owner.matches(surface.copy(accountId = "other")))
        assertFalse(owner.matches(surface.copy(environment = "pro")))
    }

    @Test fun storageKeysDoNotContainRawAccountFieldsAndSeparateEveryOwnerField() {
        val owner = TrustedCallerAccountOwner.parse(fields, "test")!!
        assertTrue(owner.storageKey().matches(Regex("[0-9a-f]{64}")))
        assertFalse(owner.storageKey().contains(owner.phone))
        for (other in listOf(owner.copy(accountId = "other"), owner.copy(phone = "other"),
            owner.copy(loginEpoch = 4), owner.copy(environment = "pro"))) {
            assertNotEquals(owner.storageKey(), other.storageKey())
        }
    }
}
