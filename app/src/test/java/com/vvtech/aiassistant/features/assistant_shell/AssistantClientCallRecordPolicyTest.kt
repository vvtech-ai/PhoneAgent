package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.callengine.AssistantCallMode
import com.vvtech.aiassistant.callengine.AssistantCallRequest
import com.vvtech.aiassistant.callengine.AssistantClientCallResult
import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AssistantClientCallRecordPolicyTest {
    @Test
    fun `normal call record hides technical sip failure`() {
        val record = buildAssistantClientCallRecord(
            AssistantClientCallResult(
                sessionId = "call-1",
                request = AssistantCallRequest(
                    phoneNumber = "15400000000",
                    countryDialCode = "86",
                    mode = AssistantCallMode.NORMAL
                ),
                startedAtMillis = 1_000L,
                connectedAtMillis = null,
                endedAtMillis = 2_000L,
                success = false,
                failureReason = "SIP INVITE 失败：503 Service Unavailable",
                failureKind = CallFailureKind.SERVICE_UNAVAILABLE,
                transcripts = emptyList()
            )
        )

        assertEquals("暂时无法接通，请稍后重试", record.resultText)
        assertFalse(record.resultText.contains("503"))
    }

    @Test
    fun `translation call record hides technical sip failure`() {
        val record = buildTranslationCallRecord(
            state = TranslationCallUiState(
                callId = "call-2",
                startedAtMs = 1_000L,
                failureReason = "SIP INVITE 失败：503 Service Unavailable",
                failureKind = CallFailureKind.SERVICE_UNAVAILABLE
            ),
            success = false,
            endedAtMillis = 2_000L
        )

        assertEquals("暂时无法接通，请稍后重试", record.resultText)
        assertFalse(record.resultText.contains("Service Unavailable"))
    }
}
