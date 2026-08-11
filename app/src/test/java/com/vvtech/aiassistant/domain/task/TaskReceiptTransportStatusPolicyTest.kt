package com.vvtech.aiassistant.domain.task

import org.junit.Assert.assertEquals
import org.junit.Test

class TaskReceiptTransportStatusPolicyTest {
    @Test
    fun semanticOutcomesMapExactlyLikeTheBackendTransportContract() {
        val expected = linkedMapOf<String?, String>(
            "SUCCESS" to "COMPLETED",
            "FAILED" to "FAILED",
            "UNCLEAR" to "UNCLEAR",
            "USER_CANCELLED" to "CANCELLED",
            "NEEDS_RECALL" to "FAILED",
            "UNKNOWN" to "FAILED",
            null to "FAILED",
        )

        assertEquals(
            expected,
            expected.keys.associateWith(TaskReceiptTransportStatusPolicy::normalize),
        )
    }
}
