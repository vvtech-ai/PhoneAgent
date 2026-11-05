package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class AlipayResultStatusTest {
    @Test fun onlyNumericStatusLeavesTheSdkResult() {
        for (code in listOf("6001", "4000", "9000", "8000", "6004", "7001")) {
            assertEquals(mapOf("nativeResultStatus" to code), AlipayResultStatus.project(mapOf(
                "resultStatus" to code, "memo" to "synthetic memo",
                "result" to "synthetic provider result"
            )))
        }
    }

    @Test fun absentMalformedOrTextStatusNeverLeavesTheBridge() {
        assertEquals(emptyMap<String, String>(), AlipayResultStatus.project(null))
        for (code in listOf("", "6001 ", " 6001", "canceled", "12345", "١٢٣٤")) {
            assertEquals(emptyMap<String, String>(), AlipayResultStatus.project(mapOf("resultStatus" to code)))
        }
    }
}
