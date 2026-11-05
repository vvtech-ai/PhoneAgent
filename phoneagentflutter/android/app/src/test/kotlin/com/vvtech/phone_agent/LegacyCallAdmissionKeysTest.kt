package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class LegacyCallAdmissionKeysTest {
    private val digest = "1e0eef211fb5804eafbae5c38a3fb3267edf5d83ced77dcd9168ca061227a719"

    @Test fun exactPrefixOnly() {
        assertEquals(listOf(digest), LegacyCallAdmissionKeys.validate(listOf(digest)))
        assertEquals("task_call_points_notice_$digest", LegacyCallAdmissionKeys.preferenceKey(digest))
    }

    @Test fun rejectsRawNamesPathsDuplicatesAndMalformedDigests() {
        for (values in listOf(emptyList<Any>(), listOf("../account_identity"),
            listOf(digest.uppercase()), listOf(digest, digest), listOf(1),
            listOf("a".repeat(63)), listOf("g".repeat(64)))) {
            assertThrows(IllegalArgumentException::class.java) { LegacyCallAdmissionKeys.validate(values) }
        }
    }

    @Test fun boundsRequestBeforePreferenceAccess() {
        val values = (1..1024).map { it.toString(16).padStart(64, '0') }
        assertEquals(1024, LegacyCallAdmissionKeys.validate(values).size)
        assertThrows(IllegalArgumentException::class.java) {
            LegacyCallAdmissionKeys.validate(values + "f".repeat(64))
        }
    }
}
