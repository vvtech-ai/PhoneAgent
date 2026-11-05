package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class TrustedCallerSurfaceTest {
    private fun surface(token: String = "a".repeat(32)) = TrustedCallerSurface(
        token, "synthetic-account", "synthetic-phone", 3, "test"
    )

    @Test fun oldReleaseCannotCloseNewPageForSameAccount() {
        val registry = TrustedCallerSurfaceRegistry()
        val old = surface()
        val current = surface("b".repeat(32))
        registry.bind(old)
        registry.bind(current)
        assertFalse(registry.release(old))
        assertTrue(registry.isCurrent(current))
        assertTrue(registry.release(current))
        assertFalse(registry.release(current))
    }

    @Test fun phoneEpochAccountAndEnvironmentChangesInvalidateOldOwner() {
        val old = surface()
        for (current in listOf(
            old.copy(accountId = "other-synthetic"),
            old.copy(phone = "other-synthetic-phone"),
            old.copy(loginEpoch = 4),
            old.copy(environment = "pro")
        )) {
            val registry = TrustedCallerSurfaceRegistry()
            registry.bind(current)
            assertFalse(registry.isCurrent(old))
            assertFalse(registry.release(old))
            assertTrue(registry.isCurrent(current))
        }
    }

    @Test fun nativeBoundaryAcceptsOnlyCompleteIntegerOwnerAndValidToken() {
        val expected = surface()
        assertEquals(expected, TrustedCallerSurface.parse(expected.report()))
        for ((field, value) in listOf(
            "surfaceToken" to "invalid", "accountId" to "", "phone" to "synthetic\nphone",
            "loginEpoch" to true, "loginEpoch" to 3.0, "loginEpoch" to -1,
            "accountId" to "synthetic\u007faccount", "phone" to "synthetic\u0001phone",
            "environment" to "unknown"
        )) {
            assertNull(TrustedCallerSurface.parse(expected.report() + (field to value)))
        }
        assertNull(TrustedCallerSurface.parse(emptyMap<String, Any>()))
    }

    @Test fun statusReportDoesNotContainCredentialsOrInferAuthorization() {
        val report = surface().report(mapOf(
            "status" to "readyToConfigure", "explicitSdkAuthorization" to false
        ))
        assertFalse(report.containsKey("appKey"))
        assertFalse(report.containsKey("appSecret"))
        assertEquals(false, report["explicitSdkAuthorization"])
        assertEquals(surface(), TrustedCallerSurface.parse(report))
    }
}
