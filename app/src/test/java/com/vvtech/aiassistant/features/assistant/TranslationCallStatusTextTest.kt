package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import org.junit.Assert.assertEquals
import org.junit.Test

class TranslationCallStatusTextTest {

    @Test
    fun localizeTranslationCallStatusText_shouldTranslateProviderAndFailureMessages() {
        assertEquals("翻译模型已连接", localizeTranslationCallStatusText("provider_connected"))
        assertEquals("翻译会话已失败：network timeout", localizeTranslationCallStatusText("provider_session_failed:network timeout"))
        assertEquals("已检测到双方为同语种，当前改为直连", localizeTranslationCallStatusText("Detected the same language and switched to passthrough."))
    }

    @Test
    fun localizeTranslationCallStatusText_shouldTranslateSipProgressMessages() {
        assertEquals(
            "对方正在响铃，等待接听",
            localizeTranslationCallStatusText("Remote side is ringing. Waiting for answer.")
        )
        assertEquals(
            "对方通话链路建立中",
            localizeTranslationCallStatusText("The remote side is establishing the media session.")
        )
        assertEquals(
            "翻译通话已接通，可开始双向翻译",
            localizeTranslationCallStatusText("Translation media bridge connected. Ready for bidirectional translation.")
        )
        assertEquals(
            "对方已结束实时翻译通话",
            localizeTranslationCallStatusText("Remote side ended the translation call.")
        )
    }

    @Test
    fun localizeTranslationCallStatusText_shouldTranslateRealtimeConnectedVariants() {
        assertEquals(
            "实时翻译会话已连接",
            localizeTranslationCallStatusText("Realtime translation session connected.")
        )
        assertEquals(
            "实时翻译会话已就绪",
            localizeTranslationCallStatusText("Realtime translation session is ready.")
        )
        assertEquals(
            "实时翻译已启动",
            localizeTranslationCallStatusText("Realtime translation is active.")
        )
        assertEquals(
            "翻译模型已连接",
            localizeTranslationCallStatusText("caller_to_callee:provider_connected")
        )
    }

    @Test
    fun localizeTranslationCallStatusText_shouldTranslateCallAndTranslationStates() {
        assertEquals("拨号中", localizeTranslationCallState("DIALING"))
        assertEquals("通话中", localizeTranslationCallState("CONNECTED"))
        assertEquals("识别语种中", localizeTranslationSessionState("LANGUAGE_DETECTING"))
        assertEquals("实时翻译中", localizeTranslationSessionState("TRANSLATING"))
    }

    @Test
    fun localizedForUi_shouldLocalizeResponsePayload() {
        val response = TranslationCallStatusResponse(
            callId = "call-1",
            callState = "CONNECTED",
            translationState = "LANGUAGE_DETECTING",
            provider = "QWEN_OMNI_PLUS",
            callerDetectedLanguage = "zh",
            calleeDetectedLanguage = "en",
            effectiveCallerToCalleeVoice = "Nofish",
            voiceCapability = "BUILT_IN_VOICE_ONLY",
            passthroughActive = true,
            passthroughReason = "Detected the same language and switched to passthrough.",
            statusMessage = "provider_session_ready",
            updatedAt = "2026-05-14T21:30:00Z"
        )

        val localized = response.localizedForUi()

        assertEquals("通话中", localized.callState)
        assertEquals("识别语种中", localized.translationState)
        assertEquals("已检测到双方为同语种，当前改为直连", localized.passthroughReason)
        assertEquals("翻译模型已就绪", localized.statusMessage)
    }
}
