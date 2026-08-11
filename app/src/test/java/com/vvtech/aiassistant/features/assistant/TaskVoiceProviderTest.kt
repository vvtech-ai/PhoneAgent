package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskVoiceProviderTest {

    @Test
    fun backendTaskVoiceProviderIncludesQwenAndDoubao() {
        assertTrue(isBackendTaskVoiceProvider("qwen"))
        assertTrue(isBackendTaskVoiceProvider("doubao"))
        assertTrue(isBackendTaskVoiceProvider(" DOUBAO "))
    }

    @Test
    fun backendTaskVoiceProviderExcludesLegacyProviders() {
        assertFalse(isBackendTaskVoiceProvider("legacy"))
        assertFalse(isBackendTaskVoiceProvider(""))
    }
}
