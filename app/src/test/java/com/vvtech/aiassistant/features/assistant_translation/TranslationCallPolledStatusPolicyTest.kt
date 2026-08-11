package com.vvtech.aiassistant.features.assistant_translation

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallPolledStatusPolicyTest {
    @Test
    fun connectedStatusOnlyUpdatesAudioChannelStatus() {
        val plan = TranslationCallPolledStatusPolicy.apply(
            currentStatus = status(
                callState = "CONNECTED",
                translationState = "TRANSLATING",
                statusMessage = "provider_session_ready"
            ),
            previousError = "previous"
        )

        assertEquals("翻译模型已就绪", plan.audioChannelStatus)
        assertNull(plan.error)
        assertFalse(plan.shouldExit)
    }

    @Test
    fun failedStatusUpdatesLocalizedErrorAndExits() {
        val plan = TranslationCallPolledStatusPolicy.apply(
            currentStatus = status(
                callState = "FAILED",
                statusMessage = "SIP INVITE rejected: 486"
            ),
            previousError = "previous"
        )

        assertEquals("SIP 呼叫邀请被拒绝：486", plan.audioChannelStatus)
        assertEquals("SIP 呼叫邀请被拒绝：486", plan.error)
        assertTrue(plan.shouldExit)
    }

    @Test
    fun endedStatusExitsWithoutForcingError() {
        val plan = TranslationCallPolledStatusPolicy.apply(
            currentStatus = status(callState = "ENDED", statusMessage = "provider_session_finished"),
            previousError = "previous"
        )

        assertEquals("翻译会话已结束", plan.audioChannelStatus)
        assertNull(plan.error)
        assertTrue(plan.shouldExit)
    }

    @Test
    fun runtimeControllerDelegatesPolledStatusApplyToPolicy() {
        val controller = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantTranslationCallRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val policy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_translation/TranslationCallPolledStatusPolicy.kt"
        ).readText(Charsets.UTF_8)
        val pollBody = controller
            .substringAfter("suspend fun pollWhileActive")
            .substringBefore("\n\n    private fun recordResult")

        assertTrue(pollBody.contains("TranslationCallPolledStatusPolicy.apply("))
        assertFalse(pollBody.contains("currentStatus.statusMessage.isNotBlank()"))
        assertFalse(pollBody.contains("currentStatus.callState.equals(\"FAILED\""))
        assertFalse(pollBody.contains("currentStatus.callState.equals(\"ENDED\""))

        assertTrue(policy.contains("localizeTranslationCallStatusText"))
        assertTrue(policy.contains("callState == \"ENDED\" || callState == \"FAILED\""))
    }

    private fun status(
        callState: String,
        translationState: String = callState,
        statusMessage: String = callState
    ): TranslationCallStatusResponse {
        return TranslationCallStatusResponse(
            callId = "call-1",
            callState = callState,
            translationState = translationState,
            provider = "qwen_omni",
            callerDetectedLanguage = "",
            calleeDetectedLanguage = "",
            effectiveCallerToCalleeVoice = "",
            voiceCapability = "BUILT_IN_VOICE_ONLY",
            subtitleItems = emptyList(),
            passthroughActive = false,
            passthroughReason = null,
            statusMessage = statusMessage,
            updatedAt = ""
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
