package com.vvtech.aiassistant.features.translation_call.backend

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackendMerchantCallStarterTest {
    @Test
    fun `retries media not ready every 500 milliseconds`() {
        val client = FakeClient(failuresBeforeSuccess = 2)
        var now = 0L
        val sleeps = mutableListOf<Long>()
        val starter = BackendMerchantCallStarter(
            client = client,
            clockMs = { now },
            sleepMs = {
                sleeps += it
                now += it
            }
        )

        val result = starter.start(request()) {}

        assertTrue(result.started)
        assertEquals(3, client.attempts)
        assertEquals(listOf(500L, 500L), sleeps)
    }

    @Test
    fun `stops retrying after bounded window`() {
        val client = FakeClient(failuresBeforeSuccess = Int.MAX_VALUE)
        var now = 0L
        val starter = BackendMerchantCallStarter(
            client = client,
            clockMs = { now },
            sleepMs = { now += it }
        )

        val error = runCatching { starter.start(request()) {} }.exceptionOrNull()

        assertTrue(error is BackendTranslationHttpException)
        assertEquals(21, client.attempts)
    }

    private fun request() = BackendStartMerchantCallRequest(
        callSessionId = "call-1",
        merchantPhone = "+14155550100",
        voiceProvider = "twilio",
        userId = "user-1"
    )

    private class FakeClient(
        private val failuresBeforeSuccess: Int
    ) : BackendTranslationClient {
        var attempts = 0
        override fun loadLanguageCatalog(): BackendTranslationLanguageCatalog =
            error("not used")
        override fun createSession(
            request: BackendCreateCallRequest
        ): BackendTranslationCallSession = error("not used")

        override fun startMerchantCall(
            request: BackendStartMerchantCallRequest
        ): BackendStartMerchantCallResult {
            attempts += 1
            if (attempts <= failuresBeforeSuccess) {
                throw BackendTranslationHttpException(
                    statusCode = 409,
                    code = "MEDIA_CHANNEL_NOT_READY",
                    environment = null,
                    message = "not ready"
                )
            }
            return BackendStartMerchantCallResult(started = true, environment = null)
        }

        override fun hangup(request: BackendHangupRequest) = Unit
    }
}
