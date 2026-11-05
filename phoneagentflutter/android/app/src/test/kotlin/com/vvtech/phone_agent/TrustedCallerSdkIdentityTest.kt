package com.vvtech.phone_agent

import org.junit.Test

class TrustedCallerSdkIdentityTest {
    @Test fun normalizesIdentityBeforeSigningWithoutChangingUserFields() {
        TrustedSdkIdentityRegression.main(emptyArray())
    }
}
