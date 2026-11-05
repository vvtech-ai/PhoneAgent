package com.vvtech.phone_agent
import org.junit.Assert.*
import org.junit.Test
class TrustedCallerGuidePolicyTest {
    @Test fun homeGuideIsSeparateFromAuthorizationAndSdkIntroduction() {
        assertTrue(TrustedCallerGuidePolicy.homeEligible(emptyMap<String, Any>()))
        for (key in listOf(TrustedCallerGuidePolicy.HOME_SEEN, TrustedCallerGuidePolicy.HOME_DISABLED,
                TrustedCallerGuidePolicy.KEY, "trusted_callee_authorized")) {
            assertFalse(TrustedCallerGuidePolicy.homeEligible(mapOf(key to true)))
            assertTrue(TrustedCallerGuidePolicy.homeEligible(mapOf(key to false)))
        }
        assertFalse(TrustedCallerGuidePolicy.homeEligible(mapOf("a".repeat(64) to true)))
        assertFalse(TrustedCallerGuidePolicy.seen(mapOf(TrustedCallerGuidePolicy.HOME_SEEN to true)))
    }
    @Test fun firstUseAndGlobalLegacyFlags() {
        assertFalse(TrustedCallerGuidePolicy.seen(emptyMap<String, Any>()))
        assertTrue(TrustedCallerGuidePolicy.seen(mapOf(TrustedCallerGuidePolicy.KEY to true)))
        assertTrue(TrustedCallerGuidePolicy.seen(mapOf("trusted_callee_authorized" to true)))
        assertTrue(TrustedCallerGuidePolicy.seen(mapOf("a".repeat(64) to true)))
        assertFalse(TrustedCallerGuidePolicy.seen(mapOf("a".repeat(64) to false)))
        assertFalse(TrustedCallerGuidePolicy.seen(mapOf("unrelated" to true)))
    }
}
