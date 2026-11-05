package com.vvtech.phone_agent

import com.alipay.sdk.app.EnvUtils
import org.junit.After
import org.junit.Assert.*
import org.junit.Test

/** Uses SDK in-memory environment only; no PayTask, merchant or provider request. */
class AlipayPaymentEnvironmentTest {
    @After fun resetSdkEnvironment() { EnvUtils.setEnv(EnvUtils.EnvEnum.ONLINE) }

    @Test fun sandboxMaterialSelectsSandbox() {
        assertEquals(EnvUtils.EnvEnum.SANDBOX, AlipayPaymentEnvironment.select("SANDBOX"))
    }

    @Test fun productionMaterialSelectsOnline() {
        assertEquals(EnvUtils.EnvEnum.ONLINE, AlipayPaymentEnvironment.select("PRODUCTION"))
    }

    @Test fun missingAndMalformedEnvironmentNeverDefaultToEitherChannel() {
        for (value in listOf(null, "", "sandbox", "SANDBOX ", "ONLINE", "PRE_SANDBOX", "test")) {
            var invoked = false
            assertThrows("Invalid environment must be rejected", IllegalArgumentException::class.java) {
                AlipayPaymentEnvironment.launch(AlipayPaymentEnvironment.select(value)) {
                    invoked = true
                }
            }
            assertFalse("Rejected material must not invoke payment", invoked)
        }
    }

    @Test fun sandboxIsSetBeforePaymentCallback() {
        EnvUtils.setEnv(EnvUtils.EnvEnum.ONLINE)
        val result = AlipayPaymentEnvironment.launch(AlipayPaymentEnvironment.select("SANDBOX")) {
            assertEquals(EnvUtils.EnvEnum.SANDBOX, EnvUtils.geEnv())
            "synthetic-outcome"
        }
        assertEquals("synthetic-outcome", result)
    }

    @Test fun productionPaymentResetsPreviousSandboxEnvironment() {
        EnvUtils.setEnv(EnvUtils.EnvEnum.SANDBOX)
        AlipayPaymentEnvironment.launch(AlipayPaymentEnvironment.select("PRODUCTION")) {
            assertEquals(EnvUtils.EnvEnum.ONLINE, EnvUtils.geEnv())
        }
    }

    @Test fun sdkFailureDoesNotChangeChosenEnvironmentOrManufactureSuccess() {
        val failure = IllegalStateException("synthetic SDK failure")
        EnvUtils.setEnv(EnvUtils.EnvEnum.ONLINE)
        val thrown = assertThrows(IllegalStateException::class.java) {
            AlipayPaymentEnvironment.launch(AlipayPaymentEnvironment.select("SANDBOX")) {
                assertEquals(EnvUtils.EnvEnum.SANDBOX, EnvUtils.geEnv())
                throw failure
            }
        }
        assertSame(failure, thrown)
    }
}
