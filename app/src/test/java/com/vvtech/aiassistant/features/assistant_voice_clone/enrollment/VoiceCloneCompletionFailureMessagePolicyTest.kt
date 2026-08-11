package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneCompletionException
import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneCompletionStage
import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceCloneCompletionFailureMessagePolicyTest {

    @Test
    fun `content mismatch tells the user how to read again`() {
        val failure = VoiceCloneCompletionException(
            httpStatus = 400,
            stage = VoiceCloneCompletionStage.ASR_CONTENT,
            cause = IllegalStateException("raw detail")
        )

        assertEquals(
            "朗读内容与提示不一致，请连续清晰地读完整句话后重新认证。",
            VoiceCloneCompletionFailureMessagePolicy.messageFor(failure)
        )
    }

    @Test
    fun `unknown stage keeps a safe generic message`() {
        val failure = VoiceCloneCompletionException(
            httpStatus = 400,
            stage = null,
            cause = IllegalStateException("raw detail")
        )

        assertEquals(
            "跟读语音处理失败，请重新认证。",
            VoiceCloneCompletionFailureMessagePolicy.messageFor(failure)
        )
    }

    @Test
    fun `clone submission failure asks for a fresh attempt instead of review`() {
        val failure = VoiceCloneCompletionException(
            httpStatus = 400,
            stage = VoiceCloneCompletionStage.CLONE_PROVIDER,
            cause = IllegalStateException("raw detail")
        )

        assertEquals(
            "声音克隆失败，请重新开始。",
            VoiceCloneCompletionFailureMessagePolicy.messageFor(failure)
        )
    }

    @Test
    fun `legacy unknown stage also releases the user to restart`() {
        val failure = VoiceCloneCompletionException(
            httpStatus = 400,
            stage = VoiceCloneCompletionStage.CLONE_SUBMISSION_UNKNOWN,
            cause = IllegalStateException("raw detail")
        )

        assertEquals(
            "声音克隆失败，请重新开始。",
            VoiceCloneCompletionFailureMessagePolicy.messageFor(failure)
        )
    }
}
