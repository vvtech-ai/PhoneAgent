package com.vvtech.aiassistant.contacts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeviceContactPhoneCountryPolicyTest {
    @Test
    fun normalizedInternationalNumberWinsAndKeepsJapaneseCountry() {
        val value = DeviceContactPhoneCountryPolicy.resolve(
            rawNumber = "090-0000-0000",
            normalizedNumber = "+819012345678"
        )

        requireNotNull(value)
        assertEquals("+819012345678", value.lookupNumber)
        assertEquals("+819012345678", value.dialNumber)
        assertEquals("JP", value.countryIso)
        assertEquals("+81", value.dialCode)
        assertEquals("9012345678", value.nationalNumber)
    }

    @Test
    fun explicitInternationalRawNumberIsUsedWhenNormalizedNumberIsMissing() {
        val value = DeviceContactPhoneCountryPolicy.resolve(
            rawNumber = "00 65 6123 4567",
            normalizedNumber = ""
        )

        requireNotNull(value)
        assertEquals("+6561234567", value.lookupNumber)
        assertEquals("+6561234567", value.dialNumber)
        assertEquals("SG", value.countryIso)
        assertEquals("61234567", value.nationalNumber)
    }

    @Test
    fun mainlandLookupStaysNationalWhileDialNumberIncludesCountryCode() {
        val value = DeviceContactPhoneCountryPolicy.resolve(
            rawNumber = "138 0013 8000",
            normalizedNumber = "+8613800138000"
        )

        requireNotNull(value)
        assertEquals("13800138000", value.lookupNumber)
        assertEquals("+8613800138000", value.dialNumber)
        assertEquals("CN", value.countryIso)
        assertEquals("+86", value.dialCode)
        assertEquals("13800138000", value.nationalNumber)
    }

    @Test
    fun normalizedMainlandLandlineKeepsRawDomesticLookupAndCanonicalDialNumber() {
        val value = DeviceContactPhoneCountryPolicy.resolve(
            rawNumber = "010-8888-6666",
            normalizedNumber = "+861088886666"
        )

        requireNotNull(value)
        assertEquals("01088886666", value.lookupNumber)
        assertEquals("+861088886666", value.dialNumber)
        assertEquals("CN", value.countryIso)
        assertEquals("+86", value.dialCode)
        assertEquals("1088886666", value.nationalNumber)
    }

    @Test
    fun localNumberKeepsExistingLookupAndUsesMainlandDialFallback() {
        val value = DeviceContactPhoneCountryPolicy.resolve(
            rawNumber = "010-8888-6666",
            normalizedNumber = ""
        )

        requireNotNull(value)
        assertEquals("01088886666", value.lookupNumber)
        assertEquals("+8601088886666", value.dialNumber)
        assertEquals("CN", value.countryIso)
        assertEquals("01088886666", value.nationalNumber)
    }

    @Test
    fun unsupportedInternationalNumberIsPreservedWithoutChinaFallback() {
        val value = DeviceContactPhoneCountryPolicy.resolve(
            rawNumber = "+44 20 7946 0958",
            normalizedNumber = ""
        )

        requireNotNull(value)
        assertEquals("+442079460958", value.lookupNumber)
        assertEquals("+442079460958", value.dialNumber)
        assertNull(value.countryIso)
        assertNull(value.dialCode)
        assertEquals("442079460958", value.nationalNumber)
    }

    @Test
    fun blankOrNonNumericContactNumberIsRejected() {
        assertNull(DeviceContactPhoneCountryPolicy.resolve("", ""))
        assertNull(DeviceContactPhoneCountryPolicy.resolve("abc", ""))
    }
}
