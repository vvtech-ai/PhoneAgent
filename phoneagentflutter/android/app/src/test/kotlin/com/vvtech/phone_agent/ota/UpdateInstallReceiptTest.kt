package com.vvtech.phone_agent.ota

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateInstallReceiptTest {
    private val digest = "a".repeat(64)

    @Test fun cancelledSameVersionInstallDoesNotComplete() {
        val receipt = UpdateInstallReceipt(100, digest)
        assertFalse(receipt.completed(100, digest))
    }

    @Test fun installingDifferentApkDoesNotCompleteThisJob() {
        val receipt = UpdateInstallReceipt(100, digest)
        assertFalse(receipt.completed(101, "b".repeat(64)))
    }

    @Test fun changedInstallTimeAndExactApkCompleteEvenForSameOrLowerVersion() {
        assertTrue(UpdateInstallReceipt(100, digest).completed(101, digest))
    }

    @Test fun absentOrMalformedInstallationEvidenceCannotComplete() {
        assertFalse(UpdateInstallReceipt(0, digest).completed(101, digest))
        assertFalse(UpdateInstallReceipt(100, "").completed(101, ""))
        assertFalse(UpdateInstallReceipt(100, "bad").completed(101, "bad"))
    }
}
