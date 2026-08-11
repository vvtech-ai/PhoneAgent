package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.domain.call.CallFailureClassifier
import com.vvtech.aiassistant.domain.call.CallFailureKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class CallFailureUserMessagePolicyTest {
    @Test
    fun `invite 503 becomes service unavailable without sip detail`() {
        val kind = CallFailureClassifier.fromSip(
            sipMethod = "INVITE",
            statusCode = 503
        )

        val message = callFailureUserMessage(kind)

        assertEquals(CallFailureKind.SERVICE_UNAVAILABLE, kind)
        assertEquals("暂时无法接通，请稍后重试", message)
        assertFalse(message.contains("SIP"))
        assertFalse(message.contains("503"))
        assertFalse(message.contains("Service Unavailable"))
    }

    @Test
    fun `common call failures use understandable fallback messages`() {
        assertEquals(
            "对方正在通话中",
            callFailureUserMessage(CallFailureKind.BUSY)
        )
        assertEquals(
            "对方暂时无法接通",
            callFailureUserMessage(CallFailureKind.TEMPORARILY_UNAVAILABLE)
        )
        assertEquals(
            "网络连接异常，请检查网络后重试",
            callFailureUserMessage(CallFailureKind.NETWORK)
        )
        assertEquals(
            "通话未接通，请稍后重试",
            callFailureUserMessage(CallFailureKind.UNKNOWN)
        )
    }
}
