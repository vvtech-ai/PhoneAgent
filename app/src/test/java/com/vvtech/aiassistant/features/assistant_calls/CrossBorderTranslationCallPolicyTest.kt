package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CrossBorderTranslationCallPolicyTest {

    @Test
    fun crossBorderTranslationRequiresConfirmation() {
        assertTrue(shouldConfirmCrossBorderTranslationCall(true, "CN", "JP"))
        assertTrue(shouldConfirmCrossBorderTranslationCall(true, "cn", "US"))
    }

    @Test
    fun sameCountryTranslationDoesNotRequireConfirmation() {
        assertFalse(shouldConfirmCrossBorderTranslationCall(true, "CN", "cn"))
    }

    @Test
    fun ordinaryCallDoesNotRequireCrossBorderTranslationConfirmation() {
        assertFalse(shouldConfirmCrossBorderTranslationCall(false, "CN", "JP"))
    }

    @Test
    fun unknownCountryDoesNotCreateFalseCrossBorderMatch() {
        assertFalse(shouldConfirmCrossBorderTranslationCall(true, null, "JP"))
        assertFalse(shouldConfirmCrossBorderTranslationCall(true, "CN", ""))
    }
}
