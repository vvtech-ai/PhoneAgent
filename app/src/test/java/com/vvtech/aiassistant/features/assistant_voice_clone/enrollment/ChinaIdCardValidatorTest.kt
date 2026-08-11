package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChinaIdCardValidatorTest {

    @Test
    fun `accepts valid mainland identity number with checksum`() {
        assertTrue(ChinaIdCardValidator.isValid("11010519491231002X"))
        assertTrue(ChinaIdCardValidator.isValid("11010519491231002x"))
    }

    @Test
    fun `rejects malformed date and checksum`() {
        assertFalse(ChinaIdCardValidator.isValid("11010519491331002X"))
        assertFalse(ChinaIdCardValidator.isValid("110105194912310021"))
        assertFalse(ChinaIdCardValidator.isValid("123"))
    }
}
