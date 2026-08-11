package com.vvtech.aiassistant.features.translation_call.data

import com.vvtech.aiassistant.domain.translation.TranslationCallPlan
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionGateway
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RegionAwareTranslationCallGatewayTest {
    @Test
    fun `routes local and backend plans without fallback`() {
        val local = FakeGateway()
        val backend = FakeGateway()
        val gateway = RegionAwareTranslationCallGateway(local, backend)

        gateway.start(request(TranslationCallTransport.LocalSipDomestic)) {}
        assertEquals(1, local.starts)
        assertEquals(0, backend.starts)

        gateway.start(request(TranslationCallTransport.BackendWebRtc)) {}
        assertEquals(1, backend.starts)
        assertTrue(local.hungUp)
        assertFalse(backend.hungUp)
    }

    private fun request(transport: TranslationCallTransport) =
        TranslationCallSessionRequest(
            callId = transport.name,
            plan = TranslationCallPlan(
                locationCountryIso = if (transport == TranslationCallTransport.BackendWebRtc) {
                    "US"
                } else {
                    "CN"
                },
                locationSource = TranslationRegionSource.LiveLocation,
                targetE164 = "+14155550100",
                transport = transport,
                provider = if (transport == TranslationCallTransport.BackendWebRtc) {
                    TranslationRealtimeProvider.Gemini
                } else {
                    TranslationRealtimeProvider.Qwen
                },
                sipAccountId = if (transport == TranslationCallTransport.BackendWebRtc) {
                    null
                } else {
                    "21311775"
                },
                serviceRegion = TranslationServiceRegion.Default
            ),
            myLanguage = "zh",
            peerLanguage = "en"
        )

    private class FakeGateway : TranslationCallSessionGateway {
        var starts = 0
        var hungUp = false
        override fun start(
            request: TranslationCallSessionRequest,
            onEvent: (TranslationCallSessionEvent) -> Unit
        ) {
            starts += 1
        }
        override fun setMuted(muted: Boolean) = Unit
        override fun setSpeakerEnabled(enabled: Boolean) = Unit
        override fun sendDtmf(digit: Char) = Unit
        override fun hangup() {
            hungUp = true
        }
        override fun release() = Unit
    }
}
