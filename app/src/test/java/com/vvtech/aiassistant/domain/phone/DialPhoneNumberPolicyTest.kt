package com.vvtech.aiassistant.domain.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DialPhoneNumberPolicyTest {
    @Test
    fun `china mobile accepts eleven digit national number`() {
        assertNull(DialPhoneNumberPolicy.validationMessage("CN", "15915874361"))
    }

    @Test
    fun `china mobile rejects twelve digit national number before dialing`() {
        assertEquals(
            "请输入正确的手机号码",
            DialPhoneNumberPolicy.validationMessage("CN", "159158743619")
        )
    }

    @Test
    fun `non china number keeps existing generic validation path`() {
        assertNull(DialPhoneNumberPolicy.validationMessage("US", "4155550123"))
    }

    @Test
    fun `china landline system target removes domestic trunk prefix`() {
        assertEquals(
            "+861088886666",
            DialPhoneNumberPolicy.systemDialTarget(
                countryIso = "CN",
                countryDialCode = "+86",
                nationalNumber = "01088886666"
            )
        )
    }

    @Test
    fun `china mobile system target keeps national body`() {
        assertEquals(
            "+8613800138000",
            DialPhoneNumberPolicy.systemDialTarget(
                countryIso = "CN",
                countryDialCode = "+86",
                nationalNumber = "13800138000"
            )
        )
    }

    @Test
    fun `blank system target stays blank`() {
        assertEquals(
            "",
            DialPhoneNumberPolicy.systemDialTarget(
                countryIso = "CN",
                countryDialCode = "+86",
                nationalNumber = ""
            )
        )
    }
}
