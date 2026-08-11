package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.contacts.DeviceContactPhoneRow
import org.junit.Assert.assertEquals
import org.junit.Test

class DialContactDirectoryStateTest {
    @Test
    fun dialContactUsesCanonicalDialNumberInsteadOfHomeLookupNumber() {
        val entry = DeviceContactPhoneRow(
            contactId = "1",
            displayName = "张三",
            phoneNumber = "13800138000",
            dialNumber = "+8613800138000",
            countryIso = "CN",
            dialCode = "+86",
            nationalNumber = "13800138000"
        ).toDialContactEntry()

        assertEquals("+8613800138000", entry.phoneNumber)
        assertEquals("张三", entry.displayName)
    }
}
