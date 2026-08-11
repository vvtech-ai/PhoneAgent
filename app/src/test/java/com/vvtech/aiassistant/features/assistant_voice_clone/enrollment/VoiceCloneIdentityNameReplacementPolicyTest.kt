package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCloneIdentityNameReplacementPolicyTest {

    @Test
    fun `changed verified name requires replacement confirmation`() {
        assertTrue(
            requiresIdentityNameReplacement(
                verifiedName = "张三",
                candidateName = " 李四 "
            )
        )
    }

    @Test
    fun `same normalized name and missing verified name do not preempt server check`() {
        assertFalse(requiresIdentityNameReplacement(" 张三 ", "张三"))
        assertFalse(requiresIdentityNameReplacement(null, "李四"))
    }
}
