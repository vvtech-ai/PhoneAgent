package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FinalContactMethodPolicyTest {
    @Test
    fun normalizesMainlandContactPhoneForValidationAndMasking() {
        assertEquals("13800138000", normalizeMainlandPhone("+86 138-0013-8000"))
        assertEquals("13800138000", normalizeMainlandPhone("86 138 0013 8000"))
        assertEquals("", normalizeMainlandPhone("010-7777-8888"))
        assertNull(validatePersonalInfoInput("张三", "+86 138-0013-8000"))
        assertEquals("请输入正确的手机号码", validatePersonalInfoInput("张三", "010-7777-8888"))
        assertEquals("138****8000", maskPhone("+86 138-0013-8000"))
    }

    @Test
    fun loginPhoneInputNormalizesCountryCodeAndRejectsInvalidPrefixes() {
        assertEquals("13800138000", normalizeLoginMainlandPhone("+86 138-0013-8000"))
        assertEquals("13800138000", sanitizeLoginPhoneInput("0086 138 0013 8000", ""))
        assertEquals("1", sanitizeLoginPhoneInput("12", "1"))
        assertEquals("", sanitizeLoginPhoneInput("29800138000", ""))
    }

    @Test
    fun outboundDialNumberKeepsFixedLineAndInternationalShapes() {
        assertEquals("01077778888", normalizeOutboundDialNumber("010-7777 8888"))
        assertEquals("01077778888", normalizeOutboundDialNumber("+86 10 7777 8888"))
        assertEquals("13800138000", normalizeOutboundDialNumber("＋８６ １３８－００１３－８０００"))
        assertEquals("+14085551212", normalizeOutboundDialNumber("+1 (408) 555-1212"))
    }
}
