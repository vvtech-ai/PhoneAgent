package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceCloneReadAloudGuidanceTest {

    @Test
    fun `guidance explains pace and digit pronunciation`() {
        assertEquals(
            "请使用正常语速，连续清晰地读完整句话；数字按中文读音读出，例如 7 读作“七”。",
            voiceCloneReadAloudGuidance
        )
    }
}
