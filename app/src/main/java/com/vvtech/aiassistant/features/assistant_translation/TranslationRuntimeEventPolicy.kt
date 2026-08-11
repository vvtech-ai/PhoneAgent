package com.vvtech.aiassistant.features.assistant_translation

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeDomain
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeEvent
import java.util.Locale

enum class TranslationRuntimeAudioEvent {
    Connected,
    Status,
    Error,
    Closed
}

object TranslationRuntimeEventPolicy {
    const val UserEndedReason = "USER_ENDED_THE_REALTIME_TRANSLATION_CALL"
    const val ProviderClosedReason = "PROVIDER_CLOSED"
    const val ProviderErrorReason = "PROVIDER_ERROR"
    const val LifecycleCancelledReason = "LIFECYCLE_CANCELLED"

    fun statusEvent(
        previous: TranslationCallStatusResponse?,
        current: TranslationCallStatusResponse,
        eventTypeOverride: String? = null,
        reasonOverride: String? = null
    ): RealtimeRuntimeEvent {
        val stateAfter = current.callState.ifBlank { current.translationState }
        val stateBefore = previous?.callState?.ifBlank { previous.translationState } ?: "IDLE"
        return RealtimeRuntimeEvent(
            domain = RealtimeRuntimeDomain.Translation,
            eventType = eventTypeOverride ?: eventTypeForStatus(current),
            provider = current.provider,
            stateBefore = stateBefore,
            stateAfter = stateAfter,
            reason = reasonOverride ?: closeReasonForStatus(current),
            callId = current.callId.ifBlank { previous?.callId },
            attributes = mapOf(
                "translationState" to current.translationState,
                "statusMessage" to current.statusMessage,
                "voiceCapability" to current.voiceCapability,
                "subtitleCount" to current.subtitleItems.size.toString(),
                "passthroughActive" to current.passthroughActive.toString(),
                "passthroughReason" to current.passthroughReason
            )
        )
    }

    fun userHangupEvent(
        callId: String?,
        provider: String?,
        stateBefore: String?
    ): RealtimeRuntimeEvent {
        return RealtimeRuntimeEvent(
            domain = RealtimeRuntimeDomain.Translation,
            eventType = "translation_call_user_hangup",
            provider = provider,
            stateBefore = stateBefore.ifBlankOrIdle(),
            stateAfter = "CLOSING",
            reason = UserEndedReason,
            callId = callId?.ifBlank { null }
        )
    }

    fun lifecycleCancelledEvent(
        callId: String?,
        provider: String?,
        stateBefore: String?,
        reason: String
    ): RealtimeRuntimeEvent {
        return RealtimeRuntimeEvent(
            domain = RealtimeRuntimeDomain.Translation,
            eventType = "translation_call_lifecycle_cancelled",
            provider = provider,
            stateBefore = stateBefore.ifBlankOrIdle(),
            stateAfter = "CLOSED",
            reason = LifecycleCancelledReason,
            callId = callId?.ifBlank { null },
            attributes = mapOf("requestedReason" to reason)
        )
    }

    fun audioSocketEvent(
        kind: TranslationRuntimeAudioEvent,
        callId: String?,
        provider: String?,
        currentState: String?,
        message: String? = null
    ): RealtimeRuntimeEvent {
        return RealtimeRuntimeEvent(
            domain = RealtimeRuntimeDomain.Translation,
            eventType = "translation_audio_channel_${kind.name.lowercase(Locale.ROOT)}",
            provider = provider,
            stateBefore = currentState.ifBlankOrIdle(),
            stateAfter = audioStateAfter(kind, currentState),
            reason = audioCloseReason(kind),
            callId = callId?.ifBlank { null },
            attributes = mapOf("audioMessage" to message)
        )
    }

    private fun eventTypeForStatus(status: TranslationCallStatusResponse): String {
        return when (status.callState.uppercase(Locale.ROOT)) {
            "DIALING" -> "translation_call_dialing"
            "RINGING" -> "translation_call_ringing"
            "CONNECTED" -> "translation_call_connected"
            "ENDED" -> "translation_call_ended"
            "FAILED" -> "translation_call_failed"
            else -> "translation_call_status_changed"
        }
    }

    private fun closeReasonForStatus(status: TranslationCallStatusResponse): String? {
        return when (status.callState.uppercase(Locale.ROOT)) {
            "FAILED" -> ProviderErrorReason
            "ENDED" -> ProviderClosedReason
            else -> null
        }
    }

    private fun audioStateAfter(kind: TranslationRuntimeAudioEvent, currentState: String?): String {
        return when (kind) {
            TranslationRuntimeAudioEvent.Connected -> "TRANSLATION_SOCKET_BOUND"
            TranslationRuntimeAudioEvent.Status -> currentState.ifBlankOrIdle()
            TranslationRuntimeAudioEvent.Error -> "FAILED"
            TranslationRuntimeAudioEvent.Closed -> "CLOSED"
        }
    }

    private fun audioCloseReason(kind: TranslationRuntimeAudioEvent): String? {
        return when (kind) {
            TranslationRuntimeAudioEvent.Error -> ProviderErrorReason
            TranslationRuntimeAudioEvent.Closed -> ProviderClosedReason
            else -> null
        }
    }

    private fun String?.ifBlankOrIdle(): String {
        return this?.trim()?.takeIf { it.isNotEmpty() } ?: "IDLE"
    }
}
