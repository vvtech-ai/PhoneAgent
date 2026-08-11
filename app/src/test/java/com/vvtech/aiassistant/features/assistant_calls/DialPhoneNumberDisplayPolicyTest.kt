package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Test

class DialPhoneNumberDisplayPolicyTest {
    @Test
    fun dialInputUsesAiphoneCountryGrouping() {
        assertEquals("188 2318 9131", formatDialInputForDisplay("18823189131", "CN"))
        assertEquals("502 325 8388", formatDialInputForDisplay("5023258388", "US"))
        assertEquals("090 1234 5678", formatDialInputForDisplay("09012345678", "JP"))
        assertEquals("90 1234 5678", formatDialInputForDisplay("9012345678", "JP"))
        assertEquals("6123 4567", formatDialInputForDisplay("61234567", "SG"))
    }

    @Test
    fun serviceCodeKeepsOriginalCharacters() {
        assertEquals("20142014*#", formatDialInputForDisplay("20142014*#", "CN"))
    }

    @Test
    fun historyKeepsCountryCodeAndFormatsNationalNumber() {
        assertEquals(
            "+86 188 2318 9131",
            formatDialHistoryNumberForDisplay("+8618823189131")
        )
        assertEquals(
            "+1 502 325 8388",
            formatDialHistoryNumberForDisplay("+15023258388")
        )
        assertEquals(
            "+81 90 1234 5678",
            formatDialHistoryNumberForDisplay("00819012345678")
        )
        assertEquals(
            "+65 6123 4567",
            formatDialHistoryNumberForDisplay("+6561234567")
        )
    }

    @Test
    fun callHeaderRemovesFormattingAndSupportedInternationalCode() {
        assertEquals("18823189131", dialSubscriberNumberForDisplay("+86 188 2318 9131"))
        assertEquals("5023258388", dialSubscriberNumberForDisplay("+1 (502) 325-8388"))
        assertEquals("9012345678", dialSubscriberNumberForDisplay("0081 90 1234 5678"))
        assertEquals("18823189131", dialSubscriberNumberForDisplay("188 2318 9131"))
    }
}
