package com.vvtech.aiassistant.features.assistant_timeline

import org.junit.Assert.assertEquals
import org.junit.Test

class CallAttemptIdentityPolicyTest {
    @Test
    fun prioritizesCallIdOverOtherAvailableIdentifiers() {
        val result = CallAttemptIdentityPolicy.resolve(
            CallAttemptIdentityInput(callId = "call-1", toolCallId = "tool-call-1", toolResultId = "tool-result-1")
        )

        assertEquals("call:call-1", result.value)
        assertEquals(CallAttemptIdentitySource.CallId, result.source)
    }

    @Test
    fun fallsBackToToolAndMessageIdentifiersDeterministically() {
        val toolResult = CallAttemptIdentityPolicy.resolve(CallAttemptIdentityInput(toolResultId = "result-1"))
        val message = CallAttemptIdentityPolicy.resolve(
            CallAttemptIdentityInput(messageIndex = 8, toolName = "makeCall")
        )

        assertEquals("tool-result:result-1", toolResult.value)
        assertEquals("message:8:tool:makeCall", message.value)
    }

    @Test
    fun requiresExplicitStableAnchorWhenMessageIndexIsUnavailable() {
        val result = CallAttemptIdentityPolicy.resolve(
            CallAttemptIdentityInput(toolName = "makeCall", fallbackAnchor = "legacy-message-abc")
        )

        assertEquals("fallback:legacy-message-abc:tool:makeCall", result.value)
        assertEquals(CallAttemptIdentitySource.FallbackAnchor, result.source)
    }
}
