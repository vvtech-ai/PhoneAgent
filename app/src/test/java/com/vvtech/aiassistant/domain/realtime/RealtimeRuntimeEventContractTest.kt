package com.vvtech.aiassistant.domain.realtime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RealtimeRuntimeEventContractTest {
    @Test
    fun normalizesProvidersAndLifecycleStatesAcrossDomains() {
        assertEquals(RealtimeProvider.Qwen, RealtimeProvider.fromRaw("qwen_omni"))
        assertEquals(RealtimeProvider.Doubao, RealtimeProvider.fromRaw("doubao_ast"))
        assertEquals(RealtimeProvider.Volc, RealtimeProvider.fromRaw("volc_rtc"))
        assertEquals(RealtimeProvider.Sip, RealtimeProvider.fromRaw("embedded_sip"))

        assertEquals(RealtimeLifecycleState.Connecting, RealtimeLifecycleState.fromRaw("DIALING"))
        assertEquals(RealtimeLifecycleState.Connecting, RealtimeLifecycleState.fromRaw("RINGING"))
        assertEquals(RealtimeLifecycleState.Active, RealtimeLifecycleState.fromRaw("TRANSLATING"))
        assertEquals(RealtimeLifecycleState.Active, RealtimeLifecycleState.fromRaw("LANGUAGE_DETECTING"))
        assertEquals(RealtimeLifecycleState.Closed, RealtimeLifecycleState.fromRaw("ENDED"))
        assertEquals(RealtimeLifecycleState.Failed, RealtimeLifecycleState.fromRaw("FAILED"))
    }

    @Test
    fun preservesUnknownLifecycleRawValue() {
        val normalized = normalizeRealtimeLifecycleState("provider_custom_state")

        assertEquals(RealtimeLifecycleState.Unknown, normalized.state)
        assertEquals("PROVIDER_CUSTOM_STATE", normalized.wireValue)
        assertEquals("provider_custom_state", normalized.rawValue)
        assertFalse(normalized.state.isTerminal)
    }

    @Test
    fun normalizesStableCloseReasons() {
        assertEquals(
            RealtimeCloseReason.ManualTtsInterrupt,
            RealtimeCloseReason.fromRaw("manual_tts_interrupt")
        )
        assertEquals(
            RealtimeCloseReason.ManualAsrTimeout60s,
            RealtimeCloseReason.fromRaw("manual_asr_timeout_60s")
        )
        assertEquals(
            RealtimeCloseReason.SipRegisterRejected,
            RealtimeCloseReason.fromRaw("SIP REGISTER rejected: 403")
        )
        assertEquals(
            RealtimeCloseReason.SipTimeout,
            RealtimeCloseReason.fromRaw("Timed out waiting for SIP response.")
        )
        assertEquals(
            RealtimeCloseReason.MediaBridgeUnavailable,
            RealtimeCloseReason.fromRaw("SIP answered without a usable SDP media address.")
        )
        assertEquals(RealtimeCloseReason.Unknown, RealtimeCloseReason.fromRaw("new reason"))
    }

    @Test
    fun reducerAdvancesRuntimeStateAndKeepsCorrelationIds() {
        val initial = RealtimeRuntimeState(domain = RealtimeRuntimeDomain.Translation)
        val connecting = RealtimeRuntimeStateReducer.reduce(
            initial,
            RealtimeRuntimeEvent(
                domain = RealtimeRuntimeDomain.Translation,
                eventType = "translation_call_dialing",
                provider = "qwen",
                stateBefore = "IDLE",
                stateAfter = "DIALING",
                traceId = "trace-1",
                sessionId = "session-1",
                callId = "call-1"
            )
        )

        assertEquals(RealtimeProvider.Qwen, connecting.provider)
        assertEquals(RealtimeLifecycleState.Connecting, connecting.lifecycleState)
        assertEquals("translation_call_dialing", connecting.lastEventType)
        assertEquals("trace-1", connecting.traceId)
        assertEquals("session-1", connecting.sessionId)
        assertEquals("call-1", connecting.callId)
        assertFalse(connecting.isTerminal)

        val failed = RealtimeRuntimeStateReducer.reduce(
            connecting,
            RealtimeRuntimeEvent(
                domain = RealtimeRuntimeDomain.Translation,
                eventType = "translation_call_failed",
                provider = "qwen",
                stateBefore = "DIALING",
                stateAfter = "FAILED",
                reason = "SIP INVITE rejected: 486"
            )
        )

        assertEquals(RealtimeLifecycleState.Failed, failed.lifecycleState)
        assertEquals(RealtimeCloseReason.SipInviteRejected, failed.closeReason)
        assertEquals("SIP INVITE rejected: 486", failed.rawReason)
        assertTrue(failed.isTerminal)
        assertEquals("trace-1", failed.traceId)
    }
}
