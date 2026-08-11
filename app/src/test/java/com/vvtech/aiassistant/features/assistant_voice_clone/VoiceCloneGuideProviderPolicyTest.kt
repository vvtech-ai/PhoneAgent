package com.vvtech.aiassistant.features.assistant_voice_clone

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneGuideProviderPolicyTest {

    @Test
    fun `only qwen call provider may show voice clone guide`() {
        assertTrue(shouldShowVoiceCloneGuideForCallProvider("QWEN_OMNI_PLUS"))
        assertTrue(shouldShowVoiceCloneGuideForCallProvider("QWEN_OMNI_FLASH"))
        assertTrue(shouldShowVoiceCloneGuideForCallProvider("qwen_omni_flash"))

        assertFalse(shouldShowVoiceCloneGuideForCallProvider("DOUBAO"))
        assertFalse(shouldShowVoiceCloneGuideForCallProvider(null))
        assertFalse(shouldShowVoiceCloneGuideForCallProvider(""))
        assertFalse(shouldShowVoiceCloneGuideForCallProvider("UNKNOWN"))
    }
}
