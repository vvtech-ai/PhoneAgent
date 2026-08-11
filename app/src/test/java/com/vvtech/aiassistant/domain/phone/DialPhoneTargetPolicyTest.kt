package com.vvtech.aiassistant.domain.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DialPhoneTargetPolicyTest {
    @Test
    fun `china mobile resolves domestic and keeps e164 canonical number`() {
        val target = ready("CN", "+86", "13800138000")

        assertEquals(DialPhoneNumberType.CHINA_MOBILE, target.type)
        assertEquals("+8613800138000", target.canonicalNumber)
        assertEquals("13800138000", target.networkDialNumber)
        assertEquals("+8613800138000", target.systemDialNumber)
    }

    @Test
    fun `china fixed line keeps trunk prefix for sip and removes it for e164`() {
        val target = ready("CN", "+86", "01088886666")

        assertEquals(DialPhoneNumberType.CHINA_FIXED_LINE, target.type)
        assertEquals("+861088886666", target.canonicalNumber)
        assertEquals("01088886666", target.networkDialNumber)
        assertEquals("+861088886666", target.systemDialNumber)
    }

    @Test
    fun `china service and short numbers stay national`() {
        listOf("4001234567", "8001234567", "95588", "96110", "10086", "12345", "88886666")
            .forEach { number ->
                val target = ready("CN", "+86", number)
                assertEquals(number, target.canonicalNumber)
                assertEquals(number, target.networkDialNumber)
                assertEquals(number, target.systemDialNumber)
            }
    }

    @Test
    fun `extension is removed from network target and retained as post connect dtmf`() {
        val target = ready("CN", "+86", "01088886666 转 1234")

        assertEquals("+861088886666", target.canonicalNumber)
        assertEquals("01088886666", target.networkDialNumber)
        assertEquals("1234", target.postConnectDtmf)
    }

    @Test
    fun `star separated extension is supported for dial pad input`() {
        val target = ready("CN", "+86", "01088886666*123")

        assertEquals("01088886666", target.networkDialNumber)
        assertEquals("123", target.postConnectDtmf)
    }

    @Test
    fun `emergency number is system only`() {
        val target = ready("CN", "+86", "120")

        assertEquals(DialPhoneNumberType.CHINA_EMERGENCY, target.type)
        assertTrue(target.systemOnly)
    }

    @Test
    fun `twelve digit china mobile remains invalid`() {
        val result = DialPhoneNumberPolicy.resolve("CN", "+86", "159158743619")

        assertTrue(result is DialPhoneTargetResult.Invalid)
        assertFalse(result is DialPhoneTargetResult.Ready)
    }

    private fun ready(countryIso: String, dialCode: String, raw: String): DialPhoneTarget =
        (DialPhoneNumberPolicy.resolve(countryIso, dialCode, raw) as DialPhoneTargetResult.Ready)
            .target
}
