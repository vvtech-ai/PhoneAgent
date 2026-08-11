package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import com.vvtech.aiassistant.domain.translation.TranslationCallPlan
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallCoordinatorTest {
    private val gateway = FakeGateway()
    private var nowMs = 1_000L
    private val coordinator = TranslationCallCoordinator(
        gateway = gateway,
        clock = { nowMs },
        idFactory = { "call-new" }
    )

    @Test
    fun `stale call event cannot mutate active call`() {
        assertTrue(coordinator.start(plan(), "zh", "en"))

        gateway.emit(
            TranslationCallSessionEvent.PhaseChanged(
                callId = "call-old",
                phase = TranslationCallPhase.Connected
            )
        )

        assertEquals(TranslationCallPhase.Preflight, coordinator.state.value.phase)
    }

    @Test
    fun `environment and transcript update the same active call`() {
        coordinator.start(plan(), "zh", "en")
        gateway.emit(
            TranslationCallSessionEvent.EnvironmentChanged(
                callId = "call-new",
                patch = TranslationCallEnvironmentPatch(
                    version = 1,
                    network = available(),
                    sip = available(),
                    model = available()
                )
            )
        )
        gateway.emit(
            TranslationCallSessionEvent.Transcript(
                callId = "call-new",
                item = transcript("segment-1", "你好")
            )
        )
        gateway.emit(
            TranslationCallSessionEvent.Transcript(
                callId = "call-new",
                item = transcript("segment-1", "你好啊")
            )
        )

        assertEquals(
            TranslationEnvironmentState.Available,
            coordinator.state.value.environment?.overallStatus
        )
        assertEquals(1, coordinator.state.value.transcripts.size)
        assertEquals("你好啊", coordinator.state.value.transcripts.single().sourceText)
    }

    @Test
    fun `unavailable environment blocks new transcript`() {
        coordinator.start(plan(), "zh", "en")
        gateway.emit(
            TranslationCallSessionEvent.EnvironmentChanged(
                callId = "call-new",
                patch = TranslationCallEnvironmentPatch(
                    version = 2,
                    network = available(),
                    sip = available(),
                    model = TranslationEnvironmentComponent(
                        TranslationEnvironmentState.Unavailable
                    )
                )
            )
        )
        gateway.emit(
            TranslationCallSessionEvent.Transcript(
                callId = "call-new",
                item = transcript("segment-2", "不应显示")
            )
        )

        assertTrue(coordinator.state.value.transcripts.isEmpty())
    }

    @Test
    fun `controls delegate and terminal event is idempotent`() {
        coordinator.start(plan(), "zh", "en")
        coordinator.dispatch(TranslationCallUiAction.ToggleMuted)
        coordinator.dispatch(TranslationCallUiAction.ToggleSpeaker)
        coordinator.dispatch(TranslationCallUiAction.SendDtmf('#'))
        coordinator.dispatch(TranslationCallUiAction.Hangup)
        gateway.emit(TranslationCallSessionEvent.Ended("call-new"))
        gateway.emit(TranslationCallSessionEvent.Failure("call-new", "late"))

        assertTrue(gateway.mutedValue)
        assertFalse(gateway.speaker)
        assertEquals('#', gateway.dtmf)
        assertTrue(gateway.hungUp)
        assertEquals(TranslationCallPhase.Failed, coordinator.state.value.phase)
        assertEquals("", coordinator.state.value.failureReason)
    }

    @Test
    fun `sip failure keeps technical detail and structured presentation kind`() {
        coordinator.start(plan(), "zh", "en")

        gateway.emit(
            TranslationCallSessionEvent.Failure(
                callId = "call-new",
                message = "SIP INVITE 失败：503 Service Unavailable",
                sipMethod = "INVITE",
                sipStatusCode = 503
            )
        )

        assertEquals(TranslationCallPhase.Failed, coordinator.state.value.phase)
        assertEquals(
            CallFailureKind.SERVICE_UNAVAILABLE,
            coordinator.state.value.failureKind
        )
        assertEquals(
            "SIP INVITE 失败：503 Service Unavailable",
            coordinator.state.value.failureReason
        )
    }

    private fun plan() = TranslationCallPlan(
        locationCountryIso = "US",
        locationSource = TranslationRegionSource.LiveLocation,
        targetE164 = "+81333445111",
        transport = TranslationCallTransport.BackendWebRtc,
        provider = TranslationRealtimeProvider.Gemini,
        sipAccountId = null,
        serviceRegion = TranslationServiceRegion.UnitedStates
    )

    private fun available() = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Available
    )

    private fun transcript(id: String, text: String) = TranslationCallTranscriptItem(
        segmentId = id,
        sourceLeg = "user",
        sourceLanguage = "zh",
        sourceText = text,
        translatedLanguage = "en",
        translatedText = "hello",
        final = true
    )

    private class FakeGateway : TranslationCallSessionGateway {
        private var listener: ((TranslationCallSessionEvent) -> Unit)? = null
        var mutedValue = false
        var speaker = true
        var dtmf: Char? = null
        var hungUp = false

        override fun start(
            request: TranslationCallSessionRequest,
            onEvent: (TranslationCallSessionEvent) -> Unit
        ) {
            listener = onEvent
        }

        override fun setMuted(muted: Boolean) {
            mutedValue = muted
        }

        override fun setSpeakerEnabled(enabled: Boolean) {
            speaker = enabled
        }

        override fun sendDtmf(digit: Char) {
            dtmf = digit
        }

        override fun hangup() {
            hungUp = true
        }

        override fun release() = Unit
        fun emit(event: TranslationCallSessionEvent) = listener?.invoke(event)
    }
}
