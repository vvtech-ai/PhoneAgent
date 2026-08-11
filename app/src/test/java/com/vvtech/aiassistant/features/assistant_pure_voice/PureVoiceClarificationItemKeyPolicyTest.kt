package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class PureVoiceClarificationItemKeyPolicyTest {
    @Test
    fun unrelatedLeadingStepDoesNotChangeExistingItemKeys() {
        val existing = listOf(
            step(VoiceRole.User, "帮我订餐"),
            step(VoiceRole.Assistant, "请问几位？"),
            receiptStep(),
        )

        val originalKeys = PureVoiceClarificationItemKeyPolicy.keys(existing)
        val shiftedKeys = PureVoiceClarificationItemKeyPolicy.keys(
            listOf(step(VoiceRole.Assistant, "历史提示")) + existing
        )

        assertEquals(originalKeys, shiftedKeys.drop(1))
    }

    @Test
    fun repeatedMessagesStillReceiveUniqueKeys() {
        val repeated = step(VoiceRole.Assistant, "请稍候")
        val keys = PureVoiceClarificationItemKeyPolicy.keys(listOf(repeated, repeated.copy()))

        assertNotEquals(keys[0], keys[1])
    }

    @Test
    fun callAttemptIdentitySurvivesPresentationUpdates() {
        val original = receiptStep()
        val updated = original.copy(text = "餐厅未接听，任务未完成")

        assertEquals(
            PureVoiceClarificationItemKeyPolicy.keys(listOf(original)),
            PureVoiceClarificationItemKeyPolicy.keys(listOf(updated)),
        )
    }

    private fun step(role: VoiceRole, text: String) = ClarificationStep(
        role = role,
        text = text,
        status = "",
    )

    private fun receiptStep() = ClarificationStep(
        role = VoiceRole.Assistant,
        text = "",
        status = "FAILED",
        callResult = CallResultPayload(
            status = "FAILED",
            headline = "任务未完成",
            detail = "无人接听",
            metadata = mapOf("callAttemptId" to "attempt-1"),
        ),
    )
}
