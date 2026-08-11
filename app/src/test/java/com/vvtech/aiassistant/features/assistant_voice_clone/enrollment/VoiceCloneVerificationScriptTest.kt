package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class VoiceCloneVerificationScriptTest {

    @Test
    fun `verification script is trimmed before launching sdk`() {
        assertEquals(
            "今天计划乘坐6路公交车去图书馆。",
            requireVoiceCloneVerificationScript("  今天计划乘坐6路公交车去图书馆。  ")
        )
    }

    @Test
    fun `missing verification script fails before launching sdk`() {
        val error = assertThrows(IllegalStateException::class.java) {
            requireVoiceCloneVerificationScript(null)
        }

        assertEquals("声音克隆服务版本未同步，请稍后重试。", error.message)
    }
}
