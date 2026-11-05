package com.vvtech.phone_agent

import org.junit.Assert.assertEquals
import org.junit.Test

class LocationPermissionPolicyTest {
    @Test fun firstRequestIsNotBlockedEvenWithoutRationale() {
        assertEquals("denied", LocationPermissionPolicy.status(false, false, false))
    }
    @Test fun grantedWinsOverHistoricalDenial() {
        assertEquals("granted", LocationPermissionPolicy.status(true, true, false))
    }
    @Test fun denialWithRationaleCanRequestAgain() {
        assertEquals("denied", LocationPermissionPolicy.status(false, true, true))
    }
    @Test fun requestedAndCannotRequestAgainGoesToSettings() {
        assertEquals("blocked", LocationPermissionPolicy.status(false, true, false))
    }
}
