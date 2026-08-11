package com.vvtech.aiassistant.domain.realtime

import java.util.Locale

enum class RealtimeRuntimeDomain {
    Voice,
    Sip,
    PhoneAgent,
    Translation
}

enum class RealtimeProvider(val wireValue: String) {
    App("app"),
    Qwen("qwen"),
    Doubao("doubao"),
    Volc("volc"),
    Sip("sip"),
    Unknown("unknown");

    companion object {
        fun fromRaw(raw: String?): RealtimeProvider {
            return when (runtimeToken(raw)) {
                "APP", "LOCAL" -> App
                "QWEN", "QWEN_OMNI", "QWEN_TRANSLATION" -> Qwen
                "DOUBAO", "DOUBAO_AST", "DOUBAO_PHONE_AGENT" -> Doubao
                "VOLC", "VOLC_RTC", "VOLCENGINE" -> Volc
                "SIP", "EMBEDDED_SIP" -> Sip
                else -> Unknown
            }
        }
    }
}

enum class RealtimeLifecycleState(val wireValue: String, val isTerminal: Boolean) {
    Idle("IDLE", isTerminal = false),
    Connecting("CONNECTING", isTerminal = false),
    Ready("READY", isTerminal = false),
    Active("ACTIVE", isTerminal = false),
    Muted("MUTED", isTerminal = false),
    Reconnecting("RECONNECTING", isTerminal = false),
    Closing("CLOSING", isTerminal = false),
    Closed("CLOSED", isTerminal = true),
    Failed("FAILED", isTerminal = true),
    Unknown("UNKNOWN", isTerminal = false);

    companion object {
        fun fromRaw(raw: String?): RealtimeLifecycleState {
            return when (runtimeToken(raw)) {
                "", "IDLE" -> Idle
                "CONNECTING", "DIALING", "RINGING", "REGISTERING", "INVITING", "STARTING" -> Connecting
                "READY", "PROVIDER_READY", "PROVIDER_SESSION_READY", "TRANSLATION_SOCKET_BOUND" -> Ready
                "ACTIVE", "CONNECTED", "TRANSLATING", "LANGUAGE_DETECTING", "BYPASSING", "PROVIDER_RESPONSE_DONE" -> Active
                "MUTED", "AUDIO_MUTED" -> Muted
                "RECONNECTING", "PROVIDER_TIMEOUT_RECONNECTING" -> Reconnecting
                "CLOSING", "STOPPING", "HANGING_UP" -> Closing
                "CLOSED", "STOPPED", "ENDED", "FINISHED", "PROVIDER_SESSION_FINISHED" -> Closed
                "FAILED", "ERROR", "PROVIDER_SESSION_FAILED", "PROVIDER_RECONNECT_FAILED", "SIP_FAILED" -> Failed
                else -> Unknown
            }
        }
    }
}

data class NormalizedRealtimeLifecycleState(
    val state: RealtimeLifecycleState,
    val wireValue: String,
    val rawValue: String?
)

fun normalizeRealtimeLifecycleState(raw: String?): NormalizedRealtimeLifecycleState {
    val state = RealtimeLifecycleState.fromRaw(raw)
    val rawValue = raw?.trim()?.takeIf { it.isNotBlank() }
    return NormalizedRealtimeLifecycleState(
        state = state,
        wireValue = if (state == RealtimeLifecycleState.Unknown && rawValue != null) {
            runtimeToken(rawValue)
        } else {
            state.wireValue
        },
        rawValue = rawValue
    )
}

enum class RealtimeCloseReason(val key: String) {
    ManualRelease("manual_release"),
    ManualTtsInterrupt("manual_tts_interrupt"),
    ManualAsrTimeout60s("manual_asr_timeout_60s"),
    UserHangup("user_hangup"),
    RemoteHangup("remote_hangup"),
    ProviderClosed("provider_closed"),
    ProviderError("provider_error"),
    SipRegisterRejected("sip_register_rejected"),
    SipInviteRejected("sip_invite_rejected"),
    SipTimeout("sip_timeout"),
    SipIoError("sip_io_error"),
    MediaBridgeUnavailable("media_bridge_unavailable"),
    AudioFocusDenied("audio_focus_denied"),
    LifecycleCancelled("lifecycle_cancelled"),
    NoInterruptCapability("no_interrupt_capability"),
    Unknown("unknown");

    companion object {
        fun fromRaw(raw: String?): RealtimeCloseReason {
            val token = runtimeToken(raw)
            return when {
                token == "MANUAL_RELEASE" -> ManualRelease
                token == "MANUAL_TTS_INTERRUPT" -> ManualTtsInterrupt
                token == "MANUAL_ASR_TIMEOUT_60S" -> ManualAsrTimeout60s
                token in setOf("USER_HANGUP", "USER_ENDED", "USER_ENDED_THE_REALTIME_TRANSLATION_CALL") -> UserHangup
                token in setOf("REMOTE_HANGUP", "REMOTE_ENDED", "REMOTE_SIDE_ENDED_THE_TRANSLATION_CALL") -> RemoteHangup
                token == "PROVIDER_CLOSED" || token.startsWith("PROVIDER_CLOSED") -> ProviderClosed
                token == "PROVIDER_ERROR" || token.startsWith("PROVIDER_ERROR") -> ProviderError
                token.startsWith("SIP_REGISTER_REJECTED") -> SipRegisterRejected
                token.startsWith("SIP_INVITE_REJECTED") || token.startsWith("SIP_INVITE_FAILED") -> SipInviteRejected
                token.contains("TIMED_OUT_WAITING_FOR_SIP") || token == "SIP_TIMEOUT" -> SipTimeout
                token.startsWith("SIP_IO_ERROR") -> SipIoError
                token.contains("MEDIA_BRIDGE") || token.contains("USABLE_SDP_MEDIA") -> MediaBridgeUnavailable
                token == "AUDIO_FOCUS_DENIED" -> AudioFocusDenied
                token == "LIFECYCLE_CANCELLED" || token == "LIFECYCLE_CANCELED" -> LifecycleCancelled
                token == "NO_INTERRUPT_CAPABILITY" -> NoInterruptCapability
                else -> Unknown
            }
        }
    }
}

data class NormalizedRealtimeCloseReason(
    val reason: RealtimeCloseReason,
    val key: String,
    val rawValue: String?
)

fun normalizeRealtimeCloseReason(raw: String?): NormalizedRealtimeCloseReason {
    val reason = RealtimeCloseReason.fromRaw(raw)
    val rawValue = raw?.trim()?.takeIf { it.isNotBlank() }
    return NormalizedRealtimeCloseReason(
        reason = reason,
        key = reason.key,
        rawValue = rawValue
    )
}

data class RealtimeRuntimeEvent(
    val domain: RealtimeRuntimeDomain,
    val eventType: String,
    val provider: String? = null,
    val stateBefore: String? = null,
    val stateAfter: String? = null,
    val reason: String? = null,
    val traceId: String? = null,
    val sessionId: String? = null,
    val callId: String? = null,
    val attributes: Map<String, String?> = emptyMap()
) {
    val normalizedProvider: RealtimeProvider = RealtimeProvider.fromRaw(provider)
    val normalizedStateBefore: NormalizedRealtimeLifecycleState = normalizeRealtimeLifecycleState(stateBefore)
    val normalizedStateAfter: NormalizedRealtimeLifecycleState = normalizeRealtimeLifecycleState(stateAfter)
    val normalizedReason: NormalizedRealtimeCloseReason = normalizeRealtimeCloseReason(reason)
}

data class RealtimeRuntimeState(
    val domain: RealtimeRuntimeDomain,
    val provider: RealtimeProvider = RealtimeProvider.Unknown,
    val lifecycleState: RealtimeLifecycleState = RealtimeLifecycleState.Idle,
    val closeReason: RealtimeCloseReason? = null,
    val lastEventType: String? = null,
    val traceId: String? = null,
    val sessionId: String? = null,
    val callId: String? = null,
    val rawState: String? = null,
    val rawReason: String? = null
) {
    val isTerminal: Boolean
        get() = lifecycleState.isTerminal
}

object RealtimeRuntimeStateReducer {
    fun reduce(
        state: RealtimeRuntimeState,
        event: RealtimeRuntimeEvent
    ): RealtimeRuntimeState {
        val stateAfterProvided = !event.stateAfter.isNullOrBlank()
        val reasonProvided = !event.reason.isNullOrBlank()
        return state.copy(
            domain = event.domain,
            provider = event.normalizedProvider,
            lifecycleState = if (stateAfterProvided) {
                event.normalizedStateAfter.state
            } else {
                state.lifecycleState
            },
            closeReason = if (reasonProvided) {
                event.normalizedReason.reason
            } else {
                state.closeReason
            },
            lastEventType = event.eventType.ifBlank { state.lastEventType },
            traceId = event.traceId ?: state.traceId,
            sessionId = event.sessionId ?: state.sessionId,
            callId = event.callId ?: state.callId,
            rawState = event.normalizedStateAfter.rawValue ?: state.rawState,
            rawReason = event.normalizedReason.rawValue ?: state.rawReason
        )
    }
}

internal fun runtimeToken(raw: String?): String {
    return raw?.trim()
        ?.replace(Regex("[^A-Za-z0-9]+"), "_")
        ?.trim('_')
        ?.uppercase(Locale.ROOT)
        .orEmpty()
}
