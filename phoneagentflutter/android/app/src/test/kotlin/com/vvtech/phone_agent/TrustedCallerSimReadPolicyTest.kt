package com.vvtech.phone_agent
import org.junit.Assert.*
import org.junit.Test

class TrustedCallerSimReadPolicyTest {
    @Test fun subscriptionReadAcceptsEitherPermission() {
        assertFalse(TrustedCallerSimReadPolicy.canReadSubscription(false, false))
        assertTrue(TrustedCallerSimReadPolicy.canReadSubscription(true, false))
        assertTrue(TrustedCallerSimReadPolicy.canReadSubscription(false, true))
        assertTrue(TrustedCallerSimReadPolicy.canReadSubscription(true, true))
    }
    @Test fun blankLocalSkipsSecondSdkReadAndUsesSubscription() {
        var simReads = 0
        val number = TrustedCallerSimReadPolicy.readNumber({ "" }, { simReads++; "13900000000" }, { "13800000000" })
        assertEquals("13800000000", number)
        assertEquals(0, simReads)
    }
    @Test fun nullLocalUsesSecondSdkBeforeSubscription() {
        val number = TrustedCallerSimReadPolicy.readNumber({ null }, { "+86 13900000000" }, { error("Must not read subscription") })
        assertEquals("13900000000", number)
    }
    @Test fun invalidSdkNumberFallsBackToSubscription() {
        assertEquals("13800000000", TrustedCallerSimReadPolicy.readNumber({ "invalid" }, { error("non-null local") }, { "13800000000" }))
    }
}
