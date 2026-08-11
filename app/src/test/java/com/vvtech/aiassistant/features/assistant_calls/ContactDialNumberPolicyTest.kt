package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContactDialNumberPolicyTest {
    @Test
    fun nationalNumberUsesCurrentCountry() {
        assertEquals(
            ContactDialNumberResult.Supported("CN", "15986676060"),
            parseContactDialNumber("159 8667 6060", "CN")
        )
    }

    @Test
    fun internationalPrefixIsSeparatedFromNationalNumber() {
        assertEquals(
            ContactDialNumberResult.Supported("CN", "15986676060"),
            parseContactDialNumber("+86 159-8667-6060", "US")
        )
        assertEquals(
            ContactDialNumberResult.Supported("SG", "81234567"),
            parseContactDialNumber("0065 8123 4567", "CN")
        )
        assertEquals(
            ContactDialNumberResult.Supported("CN", "01088886666"),
            parseContactDialNumber("+86 10 8888 6666", "US")
        )
    }

    @Test
    fun canadianNanpAreaCodeIsRecognizedAsUnsupported() {
        assertTrue(
            parseContactDialNumber("+1 416 555 0100", "CN") is
                ContactDialNumberResult.UnsupportedCountry
        )
    }

    @Test
    fun currentCanadianOverlayCodesRemainUnsupported() {
        listOf("584", "600", "622", "633", "742", "873").forEach { areaCode ->
            assertTrue(
                parseContactDialNumber("+1 $areaCode 555 0100", "CN") is
                    ContactDialNumberResult.UnsupportedCountry
            )
        }
    }

    @Test
    fun nanpAreaAndExchangeCodesCannotStartWithZeroOrOne() {
        listOf("+1 000 555 0100", "+1 212 155 0100").forEach { number ->
            assertTrue(
                parseContactDialNumber(number, "CN") is ContactDialNumberResult.Invalid
            )
        }
    }

    @Test
    fun otherValidNanpAreaCodeUsesUnitedStates() {
        assertEquals(
            ContactDialNumberResult.Supported("US", "2125550100"),
            parseContactDialNumber("+1 212 555 0100", "CN")
        )
    }

    @Test
    fun nationalNumberLongerThanFourteenDigitsIsTooLong() {
        assertTrue(
            parseContactDialNumber("123456789012345", "CN") is
                ContactDialNumberResult.TooLong
        )
    }

    @Test
    fun lettersAndMisplacedPlusAreInvalidInsteadOfBeingSilentlyDropped() {
        assertTrue(
            parseContactDialNumber("abc 13800138000", "CN") is ContactDialNumberResult.Invalid
        )
        assertTrue(
            parseContactDialNumber("138+00138000", "CN") is ContactDialNumberResult.Invalid
        )
    }
}
