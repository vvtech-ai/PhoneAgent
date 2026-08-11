package com.vvtech.aiassistant.features.assistant_translation

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.domain.realtime.RealtimeCloseReason
import com.vvtech.aiassistant.domain.realtime.RealtimeLifecycleState
import com.vvtech.aiassistant.domain.realtime.RealtimeProvider
import org.junit.Assert.assertEquals
import org.junit.Test

class TranslationRuntimeEventPolicyTest {
    @Test
    fun mapsTranslationStatusToRealtimeRuntimeEvent() {
        val dialing = status(callState = "DIALING", callId = "", provider = "QWEN_TRANSLATION")
        val connected = status(callState = "CONNECTED", translationState = "TRANSLATING")

        val dialingEvent = TranslationRuntimeEventPolicy.statusEvent(
            previous = null,
            current = dialing,
            eventTypeOverride = "translation_call_start_requested"
        )
        val connectedEvent = TranslationRuntimeEventPolicy.statusEvent(
            previous = dialing,
            current = connected
        )

        assertEquals("translation_call_start_requested", dialingEvent.eventType)
        assertEquals(RealtimeLifecycleState.Idle, dialingEvent.normalizedStateBefore.state)
        assertEquals(RealtimeLifecycleState.Connecting, dialingEvent.normalizedStateAfter.state)
        assertEquals(RealtimeProvider.Qwen, dialingEvent.normalizedProvider)

        assertEquals("translation_call_connected", connectedEvent.eventType)
        assertEquals(RealtimeLifecycleState.Connecting, connectedEvent.normalizedStateBefore.state)
        assertEquals(RealtimeLifecycleState.Active, connectedEvent.normalizedStateAfter.state)
        assertEquals("call-1", connectedEvent.callId)
        assertEquals("TRANSLATING", connectedEvent.attributes["translationState"])
    }

    @Test
    fun mapsTerminalStatusReasons() {
        val connected = status(callState = "CONNECTED")
        val failed = status(callState = "FAILED", statusMessage = "SIP INVITE rejected: 486")
        val ended = status(callState = "ENDED")

        val failedEvent = TranslationRuntimeEventPolicy.statusEvent(
            previous = connected,
            current = failed
        )
        val endedEvent = TranslationRuntimeEventPolicy.statusEvent(
            previous = connected,
            current = ended,
            reasonOverride = TranslationRuntimeEventPolicy.UserEndedReason
        )

        assertEquals("translation_call_failed", failedEvent.eventType)
        assertEquals(RealtimeLifecycleState.Failed, failedEvent.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ProviderError, failedEvent.normalizedReason.reason)

        assertEquals("translation_call_ended", endedEvent.eventType)
        assertEquals(RealtimeLifecycleState.Closed, endedEvent.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.UserHangup, endedEvent.normalizedReason.reason)
    }

    @Test
    fun mapsAudioSocketEventsToRuntimeEvents() {
        val connected = TranslationRuntimeEventPolicy.audioSocketEvent(
            kind = TranslationRuntimeAudioEvent.Connected,
            callId = "call-1",
            provider = "qwen_omni",
            currentState = "CONNECTED"
        )
        val error = TranslationRuntimeEventPolicy.audioSocketEvent(
            kind = TranslationRuntimeAudioEvent.Error,
            callId = "call-1",
            provider = "qwen_omni",
            currentState = "TRANSLATION_SOCKET_BOUND",
            message = "socket failure"
        )
        val closed = TranslationRuntimeEventPolicy.audioSocketEvent(
            kind = TranslationRuntimeAudioEvent.Closed,
            callId = "call-1",
            provider = "qwen_omni",
            currentState = "TRANSLATION_SOCKET_BOUND"
        )

        assertEquals("translation_audio_channel_connected", connected.eventType)
        assertEquals(RealtimeLifecycleState.Ready, connected.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.Unknown, connected.normalizedReason.reason)

        assertEquals("translation_audio_channel_error", error.eventType)
        assertEquals(RealtimeLifecycleState.Failed, error.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ProviderError, error.normalizedReason.reason)
        assertEquals("socket failure", error.attributes["audioMessage"])

        assertEquals("translation_audio_channel_closed", closed.eventType)
        assertEquals(RealtimeLifecycleState.Closed, closed.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.ProviderClosed, closed.normalizedReason.reason)
    }

    @Test
    fun mapsUserHangupToClosingWithStableReason() {
        val event = TranslationRuntimeEventPolicy.userHangupEvent(
            callId = "call-1",
            provider = "QWEN_TRANSLATION",
            stateBefore = "CONNECTED"
        )

        assertEquals("translation_call_user_hangup", event.eventType)
        assertEquals(RealtimeLifecycleState.Closing, event.normalizedStateAfter.state)
        assertEquals(RealtimeCloseReason.UserHangup, event.normalizedReason.reason)
        assertEquals("call-1", event.callId)
    }

    private fun status(
        callId: String = "call-1",
        callState: String,
        translationState: String = callState,
        provider: String = "qwen_omni",
        statusMessage: String = callState
    ): TranslationCallStatusResponse {
        return TranslationCallStatusResponse(
            callId = callId,
            callState = callState,
            translationState = translationState,
            provider = provider,
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
}
