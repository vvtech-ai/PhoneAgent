package com.vvtech.aiassistant.features.assistant_translation

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.domain.realtime.RealtimeLifecycleState
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeDomain
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeEvent
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeState
import com.vvtech.aiassistant.domain.realtime.RealtimeRuntimeStateReducer
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger

internal class TranslationRuntimeEventRecorder {
    private var runtimeState = RealtimeRuntimeState(domain = RealtimeRuntimeDomain.Translation)

    fun reset() {
        runtimeState = RealtimeRuntimeState(domain = RealtimeRuntimeDomain.Translation)
    }

    fun recordStatus(
        previous: TranslationCallStatusResponse?,
        current: TranslationCallStatusResponse,
        eventTypeOverride: String? = null,
        reasonOverride: String? = null,
        throwable: Throwable? = null
    ) {
        record(
            TranslationRuntimeEventPolicy.statusEvent(previous, current, eventTypeOverride, reasonOverride),
            throwable
        )
    }

    fun recordAudio(
        kind: TranslationRuntimeAudioEvent,
        callId: String,
        status: TranslationCallStatusResponse?,
        starting: Boolean,
        message: String? = null
    ) {
        if (!hasRuntimeState(callId, status, starting)) return
        record(
            TranslationRuntimeEventPolicy.audioSocketEvent(
                kind = kind,
                callId = runtimeCallId(callId, status),
                provider = runtimeProvider(status),
                currentState = runtimeStateName(status),
                message = message
            )
        )
    }

    fun recordUserHangup(callId: String, status: TranslationCallStatusResponse?, starting: Boolean) {
        if (!hasRuntimeState(callId, status, starting)) return
        record(
            TranslationRuntimeEventPolicy.userHangupEvent(
                callId = runtimeCallId(callId, status),
                provider = runtimeProvider(status),
                stateBefore = runtimeStateName(status)
            )
        )
    }

    fun recordLifecycleCancelled(
        reason: String,
        callId: String,
        status: TranslationCallStatusResponse?,
        starting: Boolean
    ) {
        if (!hasRuntimeState(callId, status, starting)) return
        record(
            TranslationRuntimeEventPolicy.lifecycleCancelledEvent(
                callId = runtimeCallId(callId, status),
                provider = runtimeProvider(status),
                stateBefore = runtimeStateName(status),
                reason = reason
            )
        )
    }

    private fun record(event: RealtimeRuntimeEvent, throwable: Throwable? = null) {
        runtimeState = RealtimeRuntimeStateReducer.reduce(runtimeState, event)
        val reason = event.reason?.takeIf { it.isNotBlank() }?.let { event.normalizedReason.key }
        val logEvent = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.TRANSLATION,
            eventType = event.eventType,
            callId = event.callId ?: runtimeState.callId,
            provider = event.normalizedProvider.wireValue,
            stateBefore = event.normalizedStateBefore.wireValue,
            stateAfter = event.normalizedStateAfter.wireValue,
            reason = reason,
            attributes = event.attributes + mapOf(
                "normalizedStateBefore" to event.normalizedStateBefore.state.wireValue,
                "normalizedStateAfter" to event.normalizedStateAfter.state.wireValue
            )
        )
        if (event.normalizedStateAfter.state == RealtimeLifecycleState.Failed) {
            RuntimeStateLogger.error(logEvent, throwable)
        } else {
            RuntimeStateLogger.info(logEvent, throwable)
        }
    }

    private fun hasRuntimeState(
        callId: String,
        status: TranslationCallStatusResponse?,
        starting: Boolean
    ): Boolean {
        return starting || callId.isNotBlank() || status != null ||
            runtimeState.callId != null ||
            runtimeState.lifecycleState != RealtimeLifecycleState.Idle
    }

    private fun runtimeCallId(callId: String, status: TranslationCallStatusResponse?): String? {
        return callId.ifBlank { status?.callId.orEmpty().ifBlank { runtimeState.callId.orEmpty() } }
            .ifBlank { null }
    }

    private fun runtimeProvider(status: TranslationCallStatusResponse?): String? {
        return status?.provider?.takeIf { it.isNotBlank() } ?: runtimeState.provider.wireValue
    }

    private fun runtimeStateName(status: TranslationCallStatusResponse?): String {
        return status?.callState?.takeIf { it.isNotBlank() }
            ?: runtimeState.rawState
            ?: runtimeState.lifecycleState.wireValue
    }
}
